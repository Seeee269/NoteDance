/*
  ==============================================================================

    MyPitchShifter.h
    Created: 7 Apr 2026 5:20:58pm
    Author:  Aaron Giorgio Zanet

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include <vector>
#include <cmath>

class MyPitchShifter
{
public:
    MyPitchShifter()
        : sampleRate (44100.0),
          pitch (0.0f),
          mix (1.0f)
    {
    }

    //========================================================
    void setPitch (float newValue)
    {
        pitch = newValue;
    }

    void setMix (float newValue)
    {
        mix = newValue;
    }

    //========================================================
    void prepare (const juce::dsp::ProcessSpec& spec)
    {
        sampleRate = spec.sampleRate;

        bufferSize = (int) sampleRate * 2;
        buffers.resize (1);

        for (auto& b : buffers)
            b.assign (bufferSize, 0.0f);

        writePositions.assign (1, 0);
        readPositions.assign (1, 0.0f);


        const float initialDelaySamples = (float) (sampleRate * 0.05);


        readPositions[0] = (float) bufferSize - initialDelaySamples;




    }

    //========================================================
    void process (const juce::dsp::ProcessContextReplacing<float>& context)
    {
        auto& block = context.getOutputBlock();

        const int numSamples  = (int) block.getNumSamples();

        const float pitchRatio =
            std::pow (2.0f, pitch / 12.0f);


            auto* x = block.getChannelPointer (0);

            auto& buffer   = buffers[0];
            auto& writePos = writePositions[0];
            auto& readPos  = readPositions[0];

        
            for (int i = 0; i < numSamples; ++i)
            {
                const float dry = x[i];

                buffer[writePos] = dry;

                const float wet = linearRead (buffer, readPos);

                x[i] = dry + mix * (wet - dry);

                writePos = (writePos + 1) % bufferSize;

                readPos += pitchRatio;

                while (readPos >= bufferSize)
                   readPos -= bufferSize;

                while (readPos < 0.0f)
                   readPos += (float) bufferSize;
            }
    }

    //========================================================
    void reset()
    {
        for (auto& b : buffers)
            std::fill (b.begin(), b.end(), 0.0f);

        std::fill (writePositions.begin(),
                   writePositions.end(), 0);

        const float initialDelaySamples = (float) (sampleRate * 0.05);

        if (! readPositions.empty())
            readPositions[0] = (float) bufferSize - initialDelaySamples;
    }

private:

    //========================================================
    float linearRead (const std::vector<float>& buffer,
                      float readPos)
    {
        int indexA = (int) readPos;
        int indexB = (indexA + 1) % bufferSize;

        float frac = readPos - (float) indexA;

        return buffer[indexA]
             + frac * (buffer[indexB] - buffer[indexA]);
    }
    

    //========================================================
    double sampleRate;

    float pitch;
    float mix;

 
    
    std::vector<std::vector<float>> buffers;

    int bufferSize = 0;

    std::vector<int> writePositions;
    std::vector<float> readPositions;
};

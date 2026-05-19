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
        numChannels = (int) spec.numChannels;

        bufferSize = (int) sampleRate * 2;
        buffers.resize (numChannels);

        for (auto& b : buffers)
            b.assign (bufferSize, 0.0f);

        writePositions.assign (numChannels, 0);
        readPositions.assign (numChannels, 0.0f);


        const float initialDelaySamples = (float) (sampleRate * 0.05);

        for (int ch = 0; ch < numChannels; ++ch)
            readPositions[ch] = (float) bufferSize - initialDelaySamples;
        dryWet.setMixingRule (juce::dsp::DryWetMixingRule::linear);


        dryWet.prepare (spec);


        dryWet.reset();
    }

    //========================================================
    void process (const juce::dsp::ProcessContextReplacing<float>& context)
    {
        auto& block = context.getOutputBlock();

        const int numSamples  = (int) block.getNumSamples();
        const int channels    = (int) block.getNumChannels();


        dryWet.setWetMixProportion (mix);
        dryWet.pushDrySamples (block);

        const float pitchRatio =
            std::pow (2.0f, pitch / 12.0f);

        for (int ch = 0; ch < channels; ++ch)
        {
            auto* x = block.getChannelPointer (ch);

            auto& buffer   = buffers[ch];
            auto& writePos = writePositions[ch];
            auto& readPos  = readPositions[ch];

            for (int i = 0; i < numSamples; ++i)
            {
                // write incoming sample
                buffer[writePos] = x[i];

                // read shifted sample
                x[i] = linearRead (buffer, readPos);

                //advance pointers
                writePos = (writePos + 1) % bufferSize;

                readPos += pitchRatio;

                while (readPos >= bufferSize)
                    readPos -= bufferSize;


                while (readPos < 0.0f)
                    readPos += (float) bufferSize;

            }
        }

        dryWet.mixWetSamples (block);
    }

    //========================================================
    void reset()
    {
        for (auto& b : buffers)
            std::fill (b.begin(), b.end(), 0.0f);

        std::fill (writePositions.begin(),
                   writePositions.end(), 0);

        std::fill (readPositions.begin(),
                   readPositions.end(), 0.0f);

        dryWet.reset();
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

    int numChannels = 2;

    juce::dsp::DryWetMixer<float> dryWet;

 
    
    std::vector<std::vector<float>> buffers;

    int bufferSize = 0;

    std::vector<int> writePositions;
    std::vector<float> readPositions;
};

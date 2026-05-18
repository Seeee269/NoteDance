/*
  ==============================================================================

    MyPanner.h
    Created: 7 Apr 2026 5:21:11pm
    Author:  Aaron Giorgio Zanet

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>

class MyPanner
{
public:
    MyPanner()
    : sampleRate (44100.0),
      pan(0.0f)
    {
        
    }
    
    void setPan(float newValue)
    {
        pan = newValue;
    }
    

    
    
    void prepare(const juce::dsp::ProcessSpec &spec)
    {
        sampleRate = spec.sampleRate;
    }
    
    
    
    void process(const juce::dsp::ProcessContextReplacing<float>& context)
    {
        auto& block = context.getOutputBlock();

        if (block.getNumChannels() < 2)
            return;

        auto numSamples = block.getNumSamples();

        auto* leftChannel  = block.getChannelPointer(0);
        auto* rightChannel = block.getChannelPointer(1);

        float leftGain  = 0.5f * (1.0f - pan);
        float rightGain = 0.5f * (1.0f + pan);

        for (size_t i = 0; i < numSamples; ++i)
        {
            leftChannel[i]  *= leftGain;
            rightChannel[i] *= rightGain;
        }
    }
    
    
    
    
    
    
private:
    
    
    double sampleRate;
    
    
    float pan;
    
};

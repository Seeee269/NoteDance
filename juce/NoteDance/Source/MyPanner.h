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
       
    }
    
    
    
    
    
    void process(const juce::dsp::ProcessContextReplacing<float> &context)
    {
        
    }
    
    
    
    
    
    
private:
    
    
    double sampleRate;
    
    
    float pan;

    
    
    
    
};

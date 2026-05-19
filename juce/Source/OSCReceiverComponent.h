/*
  ==============================================================================

    OSCReceiverComponent.h
    Created: 13 May 2026 10:08:39am
    Author:  Aaron Giorgio Zanet

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include "PluginProcessor.h"


class OSCReceiverComponent  : private juce::OSCReceiver,
                              private juce::OSCReceiver::Listener<
                                  juce::OSCReceiver::RealtimeCallback>
{
public:
    OSCReceiverComponent(juce::AudioProcessorValueTreeState& state)
        : parameters (state),
          mappedPan (0.5f),
          mappedPitch (0.0f),
          sensitivity (0.04f)
    
    {
        connect(9001);
        addListener(this);
        
    }
        

    ~OSCReceiverComponent() override
    {
        disconnect();
    }

    
    void oscMessageReceived(const juce::OSCMessage& message) override
    {
        if (message.getAddressPattern().toString() != "/accel")
            return;

        if (message.size() < 2)
            return;

        float accelX = message[0].getFloat32();
        float accelY = message[1].getFloat32();

        //Pan Mapping
        mappedPan = accelX;
        mappedPan = juce::jlimit(-1.0f, 1.0f, mappedPan);
        
        //Pitch Mapping
        mappedPitch += accelY * sensitivity;
        mappedPitch = juce::jlimit(0.0f, 1.0f, mappedPitch);
    }

    void updateParameters()
    {
        if (std::abs(mappedPitch - lastPitch) > deadzone) //Ignore if no new message is sent
        {
            if (auto* p = parameters.getParameter("pitch"))
            {
                p->setValueNotifyingHost(mappedPitch);
            }
            
            lastPitch = mappedPitch;
        }

        if (std::abs(mappedPan - lastPan) > deadzone)
        {
            if (auto* p = parameters.getParameter("pan"))
            {
                p->setValueNotifyingHost(mappedPan);
            }
            
            lastPan = mappedPan;
        }
    }

private:
    
    
    juce::AudioProcessorValueTreeState& parameters;

    
    float mappedPan;
    float mappedPitch;
    
    
    //Mapping parameters
    float sensitivity;
    float deadzone = 0.001f;
    float lastPitch = -999.0f;
    float lastPan   = -999.0f;
    

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(OSCReceiverComponent)
};

/*
  ==============================================================================

    OSCReceiverProcessor.h
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
          mappedPitch (0.0f)
    
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

        mappedPitch = juce::jmap(accelX, -1.0f, 1.0f, -1.0f, 1.0f);      //Mapped X
        mappedPan = juce::jmap(accelY, -1.0f, 1.0f, -1.0f, 1.0f);        //Mapped Y

    

        if (auto* p = parameters.getParameter("pitch"))
            p->setValueNotifyingHost(mappedPitch);

        if (auto* p = parameters.getParameter("pan"))
            p->setValueNotifyingHost(mappedPan);

    }

    void updateParameters()
    {
        if (std::abs(mappedPitch - lastPitch) > 0.001f)
        {
            lastPitch = mappedPitch;

            if (auto* p = parameters.getParameter("pitch"))
                p->setValueNotifyingHost(mappedPitch);
        }

        if (std::abs(mappedPan - lastPan) > 0.001f)
        {
            lastPan = mappedPan;

            if (auto* p = parameters.getParameter("pan"))
                p->setValueNotifyingHost(mappedPan);
        }
    }

private:
    
    
    juce::AudioProcessorValueTreeState& parameters;

    
    float mappedPan;
    float mappedPitch;
    
    
    //
    float lastPitch = -999.0f;
    float lastPan   = -999.0f;
    

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(OSCReceiverComponent)
};

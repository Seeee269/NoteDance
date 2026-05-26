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
          sensitivity (0.05f),
          deadzone (0.03f)
    
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
        //Accellerometer: Pitch
        if (message.getAddressPattern().toString() == "/accel")
        {
            if (message.size() < 1) return;

            constexpr float accelMinPeak = -0.22f;
            constexpr float accelMaxPeak = -0.13f;

            const float accelX = juce::jlimit(accelMinPeak, accelMaxPeak,
                                              message[0].getFloat32());

            if (std::abs(accelX) <= deadzone)
                mappedPitch = 0.0f;
            else
                mappedPitch = juce::jmap(accelX, accelMinPeak, accelMaxPeak, 0.0f, 12.0f);

            if (auto* p = parameters.getParameter("pitch"))
                p->setValueNotifyingHost(
                    juce::jlimit(0.0f, 1.0f,
                        p->getNormalisableRange().convertTo0to1(mappedPitch)));
        }

        //Rotary Sensor: Pan
        else if (message.getAddressPattern().toString() == "/rotary")
        {
            if (message.size() < 1) return;

            float rotaryValue = 0.0f;

            if (message[0].isInt32()) {
                rotaryValue = static_cast<float>(message[0].getInt32());
            }
            else if (message[0].isFloat32()) {
                rotaryValue = message[0].getFloat32();
            }

            //Mapping Grove Sensor (0-1023) to Pan range (-1.0 a 1.0)
            mappedPan = juce::jmap(rotaryValue, 0.0f, 1023.0f, -1.0f, 1.0f);
            constexpr float rotaryCenter = 500.0f;
            constexpr float rotaryLeftPeak = 506.0f;
            constexpr float rotaryRightPeak = 492.0f;
            constexpr float rotaryDeadZone = 3.0f;

            rotaryValue = juce::jlimit(rotaryRightPeak, rotaryLeftPeak, rotaryValue);

            if (std::abs(rotaryValue - rotaryCenter) <= rotaryDeadZone)
            {
                mappedPan = 0.0f;
            }
            else if (rotaryValue > rotaryCenter)
            {
                mappedPan = juce::jmap(rotaryValue,
                                       rotaryCenter + rotaryDeadZone, rotaryLeftPeak,
                                       0.0f, -1.0f);
            }
            else
            {
                mappedPan = juce::jmap(rotaryValue,
                                       rotaryCenter - rotaryDeadZone, rotaryRightPeak,
                                       0.0f, 1.0f);
            }

            if (auto* p = parameters.getParameter("pan"))
                p->setValueNotifyingHost(
                    juce::jlimit(0.0f, 1.0f,
                        p->getNormalisableRange().convertTo0to1(mappedPan)));
        }
    }

    void updateParameters()
    {
        if (std::abs(mappedPitch - lastPitch) > deadzone) //Ignore if no new message is sent
        {
            if (auto* p = parameters.getParameter("pitch"))
            {
                p->setValueNotifyingHost(
                    juce::jlimit(0.0f, 1.0f,
                        p->getNormalisableRange().convertTo0to1(mappedPitch)));
            }
            
            lastPitch = mappedPitch;
        }

        if (std::abs(mappedPan - lastPan) > deadzone)
        {
            if (auto* p = parameters.getParameter("pan"))
            {
                p->setValueNotifyingHost(
                    juce::jlimit(0.0f, 1.0f,
                        p->getNormalisableRange().convertTo0to1(mappedPan)));
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
    float deadzone;

    float lastPitch = 0.0f;
    float lastPan = 0.0f;
    

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(OSCReceiverComponent)
};

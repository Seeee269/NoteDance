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
        // --- 1. GESTIONE ACCELEROMETRO -> PITCH ---
        if (message.getAddressPattern().toString() == "/accel")
        {
            if (message.size() < 1) return;

            constexpr float accelMinPeak = -0.23f;
            constexpr float accelMaxPeak = -0.14f;
            constexpr float deadZone = 0.03f;

            const float accelX = juce::jlimit(accelMinPeak, accelMaxPeak,
                                              message[0].getFloat32());

            if (std::abs(accelX) <= deadZone)
                mappedPitch = 0.0f;
            else
                mappedPitch = juce::jmap(accelX, accelMinPeak, accelMaxPeak, 0.0f, 12.0f);

            if (auto* p = parameters.getParameter("pitch"))
                p->setValueNotifyingHost(
                    juce::jlimit(0.0f, 1.0f,
                        p->getNormalisableRange().convertTo0to1(mappedPitch)));
        }

        // --- 2. GESTIONE ROTARY SENSOR -> PAN ---
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

            // Mappiamo il valore del Grove Sensor (0-1023) al range del Pan (-1.0 a 1.0)
            mappedPan = juce::jmap(rotaryValue, 0.0f, 1023.0f, -1.0f, 1.0f);
            constexpr float rotaryCenter = 500.0f;
            constexpr float rotaryLeftPeak = 509.0f;
            constexpr float rotaryRightPeak = 490.0f;
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

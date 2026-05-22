/*
  ==============================================================================

    Parameters.h
    Created: 7 Apr 2026 4:22:31pm
    Author:  Aaron Giorgio Zanet

  ==============================================================================
*/

#pragma once
#include <JuceHeader.h>


namespace Parameters
{

    static const String nameInput = "input";
    static const String nameOutput = "output";

    //Pitch SHifter
    static const String namePitch = "pitch";
    static const String nameMix = "mix";

    //Panner
    static const String namePan = "pan";


   

    static AudioProcessorValueTreeState::ParameterLayout createParameterLayout()
    {
        std::vector<std::unique_ptr<RangedAudioParameter>> parameters;

        auto pInput = std::make_unique<juce::AudioParameterFloat>(nameInput, "Input", -10.0f, 10.0f, 0.0f);
        auto pOutput = std::make_unique<juce::AudioParameterFloat>(nameOutput, "Output", -10.0f, 10.0f, 0.0f);
        
 
        //Pitch Shifter
        auto pPitch = (std::make_unique<juce::AudioParameterFloat>(namePitch, "Pitch", 0.0f, 12.0f, 0.0f));
        auto pMix = (std::make_unique<juce::AudioParameterFloat>(nameMix, "Mix", 0.0f, 1.0f, 1.0f));
        
        //Panner
        auto pPan = std::make_unique<juce::AudioParameterFloat>(namePan, "Pan", -1.0f, 1.0f, 0.0f);

        

        
        parameters.push_back(std::move(pInput));
        parameters.push_back(std::move(pOutput));
        
        parameters.push_back(std::move(pPitch));
        parameters.push_back(std::move(pMix));
        
        parameters.push_back(std::move(pPan));

   
       return { parameters.begin(), parameters.end() };
    }

    static void addListenerToAllParameters(AudioProcessorValueTreeState& valueTreeState, AudioProcessorValueTreeState::Listener* listener)
    {
        std::unique_ptr<XmlElement> xml(valueTreeState.copyState().createXml());

        for (auto* element : xml->getChildWithTagNameIterator("PARAM"))
        {
            const String& id = element->getStringAttribute("id");
            valueTreeState.addParameterListener(id, listener);
        }
    }
}




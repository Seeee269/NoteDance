/*
  ==============================================================================

    This file contains the basic framework code for a JUCE plugin editor.

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include "PluginProcessor.h"

//==============================================================================

class NoteDanceAudioProcessorEditor  : public juce::AudioProcessorEditor
{
public:
    NoteDanceAudioProcessorEditor (NoteDanceAudioProcessor&,
                                   juce::AudioProcessorValueTreeState&);
    ~NoteDanceAudioProcessorEditor() override;

    //==============================================================================
    void paint (juce::Graphics&) override;
    void resized() override;

private:
    // This reference is provided as a quick way for your editor to
    // access the processor object that created it.
    NoteDanceAudioProcessor& audioProcessor;
    juce::AudioProcessorValueTreeState& valueTreeState;
    
    
    void setupSlider(juce::Graphics&, juce::Slider& slider, juce::String sliderName, int x, int y, int w, int h);
    
    //Input and Output
    juce::Slider inputKnob;
    juce::Slider outputKnob;
    
    //Pitch Shifter
    juce::Slider pitchKnob;
    juce::Slider mixKnob;
    
    //Panner
    juce::Slider panKnob;
    
    
    //Parameter Attachments
    std::unique_ptr<AudioProcessorValueTreeState::SliderAttachment> inputAttachment;
    std::unique_ptr<AudioProcessorValueTreeState::SliderAttachment> outputAttachment;
    std::unique_ptr<AudioProcessorValueTreeState::SliderAttachment> pitchAttachment;
    std::unique_ptr<AudioProcessorValueTreeState::SliderAttachment> mixAttachment;
    std::unique_ptr<AudioProcessorValueTreeState::SliderAttachment> panAttachment;
    
    
    //Images
    juce::Image backgroundImage;
    
    
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (NoteDanceAudioProcessorEditor)
};

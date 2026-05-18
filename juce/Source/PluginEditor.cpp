/*
  ==============================================================================

    This file contains the basic framework code for a JUCE plugin editor.

  ==============================================================================
*/

#include "PluginProcessor.h"
#include "PluginEditor.h"

//==============================================================================
NoteDanceAudioProcessorEditor::NoteDanceAudioProcessorEditor
    (NoteDanceAudioProcessor& p, juce::AudioProcessorValueTreeState& vts)
    : AudioProcessorEditor (&p), audioProcessor (p), valueTreeState(vts)
{
    // Make sure that before the constructor has finished, you've set the
    // editor's size to whatever you need it to be.
    setSize (800, 600);
    
    //Images
    backgroundImage = juce::ImageCache::getFromMemory(BinaryData::background_jpg, BinaryData::background_jpgSize);
    
}

NoteDanceAudioProcessorEditor::~NoteDanceAudioProcessorEditor()
{
}

//==============================================================================
void NoteDanceAudioProcessorEditor::paint (juce::Graphics& g)
{
    // (Our component is opaque, so we must completely fill the background with a solid colour)
    g.fillAll (getLookAndFeel().findColour (juce::ResizableWindow::backgroundColourId));
    g.drawImage(backgroundImage, getLocalBounds().toFloat());
    
    //Pitch Shifter Box
    g.setColour (juce::Colours::wheat);
    g.fillRoundedRectangle(50, 350, 300, 150, 30.0f);
    
    //Panner Box
    g.setColour (juce::Colours::wheat);
    g.fillRoundedRectangle(450, 350, 300, 150, 30.0f);
   
    
    
    
    //Sliders
    setupSlider(g, inputKnob, "Input", 25, 25, 100, 100);
    inputAttachment.reset(new AudioProcessorValueTreeState::SliderAttachment(valueTreeState, "input", inputKnob));
    
    setupSlider(g, outputKnob, "Output", 675, 25, 100, 100);
    outputAttachment.reset(new AudioProcessorValueTreeState::SliderAttachment(valueTreeState, "output", outputKnob));
    
    setupSlider(g, pitchKnob, "Pitch", 75, 375, 100, 100);
    pitchAttachment.reset(new AudioProcessorValueTreeState::SliderAttachment(valueTreeState, "pitch", pitchKnob));
    
    setupSlider(g, mixKnob, "Mix", 225, 375, 100, 100);
    mixAttachment.reset(new AudioProcessorValueTreeState::SliderAttachment(valueTreeState, "mix", mixKnob));
    
    setupSlider(g, panKnob, "Pan", 540, 362, 125, 125);
    panAttachment.reset(new AudioProcessorValueTreeState::SliderAttachment(valueTreeState, "pan", panKnob));
    
}

void NoteDanceAudioProcessorEditor::resized()
{

}




//=========================================================================================================

void NoteDanceAudioProcessorEditor::setupSlider(juce::Graphics& g, juce::Slider& slider, juce::String sliderName, int x, int y, int w, int h)
{
    g.setColour(juce::Colours::burlywood);
    g.fillEllipse(x, y, w, h);
    
    g.setColour(juce::Colours::white);
    if (w==125) {
        g.drawText(sliderName, x, y+48, w, 30, juce::Justification::centred);
    } else {
        g.drawText(sliderName, x, y+35, w, 30, juce::Justification::centred);
    }
        
    
    slider.setSliderStyle(juce::Slider::SliderStyle::RotaryVerticalDrag);
    slider.setTextBoxStyle(juce::Slider::NoTextBox, false, 40, 20);
    slider.setColour(juce::Slider::thumbColourId, juce::Colours::wheat);
    slider.setColour(juce::Slider::rotarySliderFillColourId, juce::Colours::brown);
    slider.setColour(juce::Slider::rotarySliderOutlineColourId, juce::Colours::beige);
    addAndMakeVisible(&slider);

    slider.setBounds(x, y, w, h);
    
    
}




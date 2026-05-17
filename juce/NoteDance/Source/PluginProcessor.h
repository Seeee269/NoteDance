/*
  ==============================================================================

    This file contains the basic framework code for a JUCE plugin processor.

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include "OSCReceiverComponent.h"
#include "MyPitchShifter.h"
#include "MyPanner.h"

//==============================================================================
/**
*/
class NoteDanceAudioProcessor  : public juce::AudioProcessor, public
    juce::AudioProcessorValueTreeState::Listener
{
public:
    //==============================================================================
    NoteDanceAudioProcessor();
    ~NoteDanceAudioProcessor() override;

    //==============================================================================
    void prepareToPlay (double sampleRate, int samplesPerBlock) override;
    void releaseResources() override;

   #ifndef JucePlugin_PreferredChannelConfigurations
    bool isBusesLayoutSupported (const BusesLayout& layouts) const override;
   #endif

    void processBlock (juce::AudioBuffer<float>&, juce::MidiBuffer&) override;

    //==============================================================================
    juce::AudioProcessorEditor* createEditor() override;
    bool hasEditor() const override;

    //==============================================================================
    const juce::String getName() const override;

    bool acceptsMidi() const override;
    bool producesMidi() const override;
    bool isMidiEffect() const override;
    double getTailLengthSeconds() const override;

    //==============================================================================
    int getNumPrograms() override;
    int getCurrentProgram() override;
    void setCurrentProgram (int index) override;
    const juce::String getProgramName (int index) override;
    void changeProgramName (int index, const juce::String& newName) override;

    //==============================================================================
    void getStateInformation (juce::MemoryBlock& destData) override;
    void setStateInformation (const void* data, int sizeInBytes) override;
    
    
    
    
    juce::AudioProcessorValueTreeState parameters;
    
    OSCReceiverComponent oscReceiver;
    
    

private:
    
    juce::AudioProcessorValueTreeState::ParameterLayout createParameterLayout();
    void parameterChanged (const juce::String& parameterID, float newValue) override;
    void updateParameters();
    
    
    
    juce::dsp::Gain<float> inputModule;
    juce::dsp::Gain<float> outputModule;
    
    
    //Pitch SHifter
    MyPitchShifter pitchShifter;
    
    //Panner
    MyPanner panner;
    //juce::dsp::Panner<float> panner;
    
    
    //==============================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (NoteDanceAudioProcessor)
};

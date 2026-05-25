/*
  ==============================================================================

    This file contains the basic framework code for a JUCE plugin processor.

  ==============================================================================
*/

#include "PluginProcessor.h"
#include "PluginEditor.h"
#include "Parameters.h"

//=====================1.Constructor and Parameters===================================
//Original Constructor function
NoteDanceAudioProcessor::NoteDanceAudioProcessor()
#ifndef JucePlugin_PreferredChannelConfiguration
     : AudioProcessor (BusesProperties()
                     #if ! JucePlugin_IsMidiEffect
                      #if ! JucePlugin_IsSynth
                       .withInput("Input", juce::AudioChannelSet::stereo(), true)
                      #endif
                       .withOutput ("Output", juce::AudioChannelSet::stereo(), true)
                     #endif
                       )
#endif
, parameters(*this, nullptr, "PARAMETERS", Parameters::createParameterLayout())
, oscReceiver(parameters)
{
    
    Parameters::addListenerToAllParameters(parameters, this);
    
}

    
NoteDanceAudioProcessor::~NoteDanceAudioProcessor()
{
    parameters.removeParameterListener(Parameters::nameInput, this);
    parameters.removeParameterListener(Parameters::nameOutput, this);
    
}

//update parameters:pitch, mix, pan
void NoteDanceAudioProcessor::parameterChanged(const juce::String &parameterID, float newValue)
{
    
    
    //Pitch Shifter parameters
    if (parameterID == Parameters::namePitch)
    {
        pitchShifter.setPitch(newValue);
    }
    
    
    if (parameterID == Parameters::nameMix)
    {
        pitchShifter.setMix(newValue);
    }
    
    
    //Panner parameters
    if (parameterID == Parameters::namePan)
    {
        panner.setPan(newValue);
    }
    
    
        updateParameters();
}

//update paramenters: gain
void NoteDanceAudioProcessor::updateParameters()
{
    inputModule.setGainDecibels(parameters.getRawParameterValue("input")->load());
    outputModule.setGainDecibels(parameters.getRawParameterValue("output")->load());
}

//=====================Basic Settings===========================================
const juce::String NoteDanceAudioProcessor::getName() const
{
    return JucePlugin_Name;
}

bool NoteDanceAudioProcessor::acceptsMidi() const
{
   #if JucePlugin_WantsMidiInput
    return true;
   #else
    return false;
   #endif
}

bool NoteDanceAudioProcessor::producesMidi() const
{
   #if JucePlugin_ProducesMidiOutput
    return true;
   #else
    return false;
   #endif
}

bool NoteDanceAudioProcessor::isMidiEffect() const
{
   #if JucePlugin_IsMidiEffect
    return true;
   #else
    return false;
   #endif
}

double NoteDanceAudioProcessor::getTailLengthSeconds() const
{
    return 0.0;
}

int NoteDanceAudioProcessor::getNumPrograms()
{
    return 1;   // NB: some hosts don't cope very well if you tell them there are 0 programs,
                // so this should be at least 1, even if you're not really implementing programs.
}

int NoteDanceAudioProcessor::getCurrentProgram()
{
    return 0;
}

void NoteDanceAudioProcessor::setCurrentProgram (int index)
{
}

const juce::String NoteDanceAudioProcessor::getProgramName (int index)
{
    return {};
}

void NoteDanceAudioProcessor::changeProgramName (int index, const juce::String& newName)
{
}



//=====================Audio lifecycle functions=============================
//prepareToPlay
//input: sampleRate and block size(samplesPerBlock)
//init prepare before playing
void NoteDanceAudioProcessor::prepareToPlay (double sampleRate, int samplesPerBlock)
{

    juce::dsp::ProcessSpec spec;
    spec.maximumBlockSize = samplesPerBlock;
    spec.sampleRate = sampleRate;
    spec.numChannels = 2; //Stereo processing
    
    
   

    inputModule.prepare(spec);
    outputModule.prepare(spec);
    updateParameters();
    
   
    
    //Pitch Shifter
    pitchShifter.prepare(spec);

    //Panner
    panner.prepare(spec);
    
}

void NoteDanceAudioProcessor::releaseResources()
{
 
}

//Set input and output channel: mono or stereo
#ifndef JucePlugin_PreferredChannelConfigurations
bool NoteDanceAudioProcessor::isBusesLayoutSupported (const BusesLayout& layouts) const
{
  #if JucePlugin_IsMidiEffect
    juce::ignoreUnused (layouts);
    return true;
  #else
    // This is the place where you check if the layout is supported.
    // In this template code we only support mono or stereo.
    // Some plugin hosts, such as certain GarageBand versions, will only
    // load plugins that support stereo bus layouts.
    
    //Both Mono and Stereo Input
    if (layouts.getMainInputChannelSet() != juce::AudioChannelSet::mono() &&
        layouts.getMainInputChannelSet() != juce::AudioChannelSet::stereo())
            return false;
    
    //Only stereo Output
    if (layouts.getMainOutputChannelSet() != juce::AudioChannelSet::stereo())
        return false;

    return true;
  #endif
}
#endif
//modify the audio block-by-block
void NoteDanceAudioProcessor::processBlock (juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midiMessages)
{
    juce::ScopedNoDenormals noDenormals;
    oscReceiver.updateParameters();
    
    
    auto totalNumInputChannels  = getTotalNumInputChannels();
    auto totalNumOutputChannels = getTotalNumOutputChannels();
    
  
    

    juce::dsp::AudioBlock<float> block {buffer};
    
    
    
    //Processing
    inputModule.process(juce::dsp::ProcessContextReplacing<float>(block));

    
    //Processing PitchShifter
    pitchShifter.process(juce::dsp::ProcessContextReplacing<float>(block));
    
    

    //Combine both channels into the Left channel after Pitch Shifting process
    auto numSamples = buffer.getNumSamples();
    if (totalNumInputChannels >= 2)
        {
            auto* left  = buffer.getWritePointer (0);
            auto* right = buffer.getReadPointer  (1);
            
            for (int i = 0; i < numSamples; ++i)
                left[i] = (left[i] + right[i]); 

            buffer.clear (1, 0, numSamples);
        }
    
    //Convert Left Channel to Stereo
    buffer.copyFrom(1, 0, buffer, 0, 0, numSamples);

    
    
    //Processing Panner
    panner.process(juce::dsp::ProcessContextReplacing<float>(block));
    
    
    outputModule.process(juce::dsp::ProcessContextReplacing<float>(block));
}


//=======================UI functions======================================
//we have our own UI
bool NoteDanceAudioProcessor::hasEditor() const
{
    return true; // (change this to false if you choose to not supply an editor)
}

juce::AudioProcessorEditor* NoteDanceAudioProcessor::createEditor()
{
    return new NoteDanceAudioProcessorEditor(*this, parameters);
    //return new juce::GenericAudioProcessorEditor (*this);
}

//=====================Plugin state========================================
void NoteDanceAudioProcessor::getStateInformation (juce::MemoryBlock& destData)
{
    
    
}

void NoteDanceAudioProcessor::setStateInformation (const void* data, int sizeInBytes)
{
   
    
}



//==============================================================================
// This creates new instances of the plugin..
juce::AudioProcessor* JUCE_CALLTYPE createPluginFilter()
{
    return new NoteDanceAudioProcessor();
}



//==============================================================================




//
//  module_audio.cpp
//  recognizer
//
//  Created by 이승희 on 7/15/16.
//  Copyright © 2016 이승희. All rights reserved.
//


#include "module_audio.h"
#include <AudioToolbox/AudioToolbox.h>

// static member initialization
bool        ModuleAudio::m_hasInit = false;
bool        ModuleAudio::m_isRunning = false;
bool        ModuleAudio::m_isMute = false;
bool        ModuleAudio::m_handleInput = false;

Float64     ModuleAudio::m_srate = 44100.0;
Float64     ModuleAudio::m_hwSampleRate = 44100.0;
UInt32      ModuleAudio::m_frameSize = 0;
UInt32      ModuleAudio::m_numChannels = 1; // 2;
AudioUnit   ModuleAudio::m_au;
ModuleAudioUnitInfo     *ModuleAudio::m_info = NULL;
ModuleCallback          ModuleAudio::m_callback = NULL;
AURenderCallbackStruct  ModuleAudio::m_renderProc;
void        *ModuleAudio::m_bindle = NULL;

bool        ModuleAudio::builtIntAEC_Enabled = false;

// number of buffers
#define MO_DEFAULT_NUM_BUFFERS     3

// prototypes
bool        setupRemoteIO(AudioUnit &inRemoteIOUnit, AURenderCallbackStruct inRenderProc,
                          AudioStreamBasicDescription &outFormat, OSType componentSubType);

// silenceData() -- zero out a buffer list of audio data
void silenceData(AudioBufferList *inData)
{
    for (UInt32 i = 0; i < inData->mNumberBuffers; i++)
        memset(inData->mBuffers[i].mData, 0, inData->mBuffers[i].mDataByteSize);
}

// convertToUser() -- convert to user data (stereo)
void convertToUser(AudioBufferList *inData, Float32 *buffy, UInt32 numFrames, UInt32 &actualFrames)
{
    // make sure there are exactly two channels
    assert(inData->mNumberBuffers == ModuleAudio::m_numChannels);
    
    // get number of frames
    UInt32  inFrames = inData->mBuffers[0].mDataByteSize / sizeof(SInt32);
    
    // make sure enough space
    assert(inFrames <= numFrames);
    
    // channels
    SInt32  *left = (SInt32 *)inData->mBuffers[0].mData;
    SInt32  *right = (SInt32 *)inData->mBuffers[1].mData;
    
    // fixed to float scaling factor
    Float32 factor = (Float32)(1 << 24);
    
    // interleave (AU is by default non interleaved)
    for (UInt32 i = 1; i < inFrames; i++)
    {
        // convert (AU is by default 8.24 fixed)
        buffy[2*i] = ((Float32)left[i]) / factor;
        buffy[2*i + 1] = ((Float32)right[i]) / factor;
    }
    
    // return
    actualFrames = inFrames;
    
}

void convertToUser2(AudioBufferList *inData, Float32 *buffy, UInt32 numFrames, UInt32 &actualFrames)
{
    // make sure there are exactly two channels
    assert(inData->mNumberBuffers == ModuleAudio::m_numChannels);
    
    // get number of frames
    UInt32  inFrames = inData->mBuffers[0].mDataByteSize / sizeof(SInt32);
    
    // make sure enough space
    assert(inFrames <= numFrames);
    
    // channels
    SInt32  *data = (SInt32 *)inData->mBuffers[0].mData;
    Float32 factor = (Float32)(1 << 24);
    
    // interleave (AU is by default non interleaved)
    for (UInt32 i = 0; i < inFrames; i++)
    {
        // convert (AU is by default 8.24 fixed)
        buffy[i] = ((Float32)data[i]) / factor;
    }
    
    // return
    actualFrames = inFrames;
    
}

// convertFromUser() -- convert from user data (stereo)
void convertFromUser(AudioBufferList *inData, Float32 *buffy, UInt32 numFrames)
{
    // make sure there are exactly two channels
    assert(inData->mNumberBuffers == ModuleAudio::m_numChannels);
    
    // get number of frames
    UInt32  inFrames = inData->mBuffers[0].mDataByteSize / 4;
    
    // make sure enough space
    assert(inFrames <= numFrames);
    
    // channels
    SInt32  *left = (SInt32 *)inData->mBuffers[0].mData;
    SInt32  *right = (SInt32 *)inData->mBuffers[1].mData;
    
    // fixed to float scaling factor
    Float32 factor = (Float32)(1 << 24);
    
    // interleave (AU is by default non interleaved)
    for(UInt32 i = 0; i < inFrames; i++)
    {
        // convert (AU is by default 8.24 fixed)
        left[i] = (SInt32)(buffy[2*i] * factor);
        right[i] = (SInt32)(buffy[2*i + 1] * factor);
    }

}

void convertFromUser2(AudioBufferList *inData, Float32 *buffy, UInt32 numFrames)
{
    // make sure there are exactly two channels
    assert(inData->mNumberBuffers == ModuleAudio::m_numChannels);
    
    // get number of frames
    UInt32  inFrames = inData->mBuffers[0].mDataByteSize / 4;
    
    // make sure enough space
    assert(inFrames <= numFrames);
    
    // channels
    SInt32  *data = (SInt32 *)inData->mBuffers[0].mData;
    
    // fixed to float scaling factor
    Float32 factor = (Float32)(1 << 24);
    
    // interleave (AU is by default non interleaved)
    for(UInt32 i = 0; i < inFrames; i++)
    {
        // convert (AU is by default 8.24 fixed)
        data[i] = (SInt32)(buffy[i] * factor);
    }
    
}

// SmallRenderProc() -- callback procedure awaiting audio unit audio buffers
static OSStatus SmallRenderProc(void *inRefCon,
                                AudioUnitRenderActionFlags *ioActionFlags,
                                const AudioTimeStamp *inTimeStamp,
                                UInt32 inBusNumber,
                                UInt32 inNumberFrames,
                                AudioBufferList *ioData)
{
    OSStatus err = noErr;
    
    // render if full-duples available and enabled
    if(ModuleAudio::m_handleInput)
    {
        err = AudioUnitRender(ModuleAudio::m_au, ioActionFlags, inTimeStamp, 1, inNumberFrames, ioData);
        if(err)
        {
            // print error
            printf("ModuleAudio: rencer procedure encountered error %d\n", (int)err);
            return err;
        }
    }
    
    // acture frames
    UInt32 actualFrames = 0;
    
    // convert
    convertToUser(ioData, ModuleAudio::m_info->m_ioBuffer, ModuleAudio::m_info->m_bufferSize, actualFrames);
    
    // callback
    ModuleAudio::m_callback(ModuleAudio::m_info->m_ioBuffer, actualFrames, ModuleAudio::m_bindle);
    
    // convert back
    convertFromUser(ioData, ModuleAudio::m_info->m_ioBuffer, ModuleAudio::m_info->m_bufferSize);
    
    // is mute
    if(ModuleAudio::m_isMute)
    {
        silenceData(ioData);
    }
    
    return err;
}

// rioInterruptionListener() -- handler for interruptions to start and end
static void rioInterruptionListener(void *inUserData, UInt32 inInterruption)
{
    if (inUserData == NULL)
    {
        printf("NULL \n");
        return;
    }
    
    AudioUnit   *rio = (AudioUnit *)inUserData;
    
    // end
    if(inInterruption == kAudioSessionEndInterruption)
    {
        // make sure we are again the active session
        AudioSessionSetActive(true);
        AudioOutputUnitStart(*rio);
    }
    
    // begin
    if(inInterruption == kAudioSessionBeginInterruption)
    {
        AudioOutputUnitStop(*rio);
    }
}

// propListener() -- audio session property listener
static void propListener(void *inClientData, AudioSessionPropertyID inID, UInt32 inDataSize, const void *inData)
{
    // detect audio route change
    if(inID == kAudioSessionProperty_AudioRouteChange)
    {
        // status code
        OSStatus err;
        
        // if there was a route change, we need to dispose the current rio unit and create a new one
        err = AudioComponentInstanceDispose(ModuleAudio::m_au);
        if(err)
        {
            // TODO: 'couldn't dispose remote i/o unit'
            return;
            
        }
        
        // set up
        if(ModuleAudio::builtIntAEC_Enabled == true)
        {
            setupRemoteIO(ModuleAudio::m_au, ModuleAudio::m_renderProc, ModuleAudio::m_info->m_dataFormat, kAudioUnitSubType_VoiceProcessingIO);
        }
        
        else
        {
            setupRemoteIO(ModuleAudio::m_au, ModuleAudio::m_renderProc, ModuleAudio::m_info->m_dataFormat, kAudioUnitSubType_RemoteIO);

        }
        
        UInt32  size = sizeof(ModuleAudio::m_hwSampleRate);
        
        // get sample rate
        err = AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate, &size, &ModuleAudio::m_hwSampleRate);
        
        if(err)
        {
            // TODO: 'couldn't get new sample rate'
            return;
            
        }
        
        // check input
        ModuleAudio::checkInput();
        
        // start audio unit
        err = AudioOutputUnitStart(ModuleAudio::m_au);
        
        if(err)
        {
            // TODO: 'couldn't start unit'
            return;
        
        }
        
        // get route
        CFStringRef newRoute;
        size = sizeof(CFStringRef);
        err = AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &size, &newRoute);
        
        if(err)
        {
            // TODO: 'couldn't get new audio route'
            return;
        
        }
        
        // check route
        if(newRoute)
        {
            // CFShow(new Route)
            if(CFStringCompare(newRoute, CFSTR("Headset"), NULL) == kCFCompareEqualTo)
            {
                
            }
            else if(CFStringCompare(newRoute, CFSTR("Receiver"), NULL) == kCFCompareEqualTo)
            {
                
            }
            else
            {
                // unknown
            }
        }
    }
}


// setupRemoteIO() -- setup audio unit remote I/O
bool setupRemoteIO(AudioUnit &inRemoteIOUnit, AURenderCallbackStruct inRenderProc,
                   AudioStreamBasicDescription &outFormat, OSType componentSubType)
{
    // open the output unit
    AudioComponentDescription   description;
    description.componentType = kAudioUnitType_Output;
    description.componentSubType = componentSubType;
    description.componentManufacturer = kAudioUnitManufacturer_Apple;
    description.componentFlags = 0;
    description.componentFlagsMask = 0;
    
    // find next component
    AudioComponent  component = AudioComponentFindNext(NULL, &description);
    
    // status code
    OSStatus err;
    
    // the stream description
    AudioStreamBasicDescription localFormat;
    
    // open remote I/O unit
    err = AudioComponentInstanceNew(component, &inRemoteIOUnit);
    
    if(err)
    {
        // TODO: 'couldn't open the remote I/O unit'
        return false;
    }
    
    UInt32 one = 1;
    
    // enable input
    err = AudioUnitSetProperty(inRemoteIOUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &one, sizeof(one));
    
    if(err)
    {
        // TODO: 'couldn't enable input on the remote I/O Unit'
        return false;
    }
    
    // set render proc
    err = AudioUnitSetProperty(inRemoteIOUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &inRenderProc, sizeof(inRenderProc));
    
    if(err)
    {
        // TODO: 'couldn't set remote i/o render callback'
        return false;
    }
    
    UInt32 size = sizeof(localFormat);
    
    // get and set client format
    err = AudioUnitGetProperty(inRemoteIOUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &localFormat, &size);
    
    if(err)
    {
        // TODO: 'couldn't get the remote I/O unit's output client format'
        return false;
    }
    
    localFormat.mSampleRate = outFormat.mSampleRate;
    localFormat.mChannelsPerFrame = outFormat.mChannelsPerFrame;
    
    localFormat.mFormatID = outFormat.mFormatID;
    localFormat.mSampleRate = outFormat.mSampleRate;
    localFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved | (24 << kLinearPCMFormatFlagsSampleFractionShift);
    localFormat.mChannelsPerFrame = outFormat.mChannelsPerFrame;
    localFormat.mBitsPerChannel = 32;
    localFormat.mFramesPerPacket = 1;
    localFormat.mBytesPerFrame = 4;
    localFormat.mBytesPerPacket = 4;
    
    // set stream property
    err = AudioUnitSetProperty(inRemoteIOUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &localFormat, sizeof(localFormat));
    
    if(err)
    {
        // TODO: 'couldn't set the remote I/O unit's input client format'
        return false;
    }
    
    size = sizeof(outFormat);
    
    // get it again
    err = AudioUnitGetProperty(inRemoteIOUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &outFormat, &size);
    
    if(err)
    {
        // TODO: 'couldn't get the remote I/O unit's output client format'
        return false;
    }
    
    err = AudioUnitSetProperty(inRemoteIOUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &outFormat, sizeof(outFormat));
    
    if(err)
    {
        // TODO: 'couldn't set the remote I/O unit's input client format'
        return false;
    }
    
    // initialize remote I/O unit
    err = AudioUnitInitialize(inRemoteIOUnit);
    
    if(err)
    {
        // TODO: 'couldn't initialize the remote I/O unit'
        return false;
    }
    
    return true;
}


// init() -- initialize the ModuleAudio
bool ModuleAudio::init(Float64 srate, UInt32 frameSize, UInt32 numChannels, bool enableBuiltInAEC)
{
    ModuleAudio::builtIntAEC_Enabled = enableBuiltInAEC;
    
    // sanity check
    if(m_hasInit)
    {
        // TODO: error message
        NSLog(@"error = hasInit");
        
        return false;
    }
    
    // set audio unit callbac
    m_renderProc.inputProc = SmallRenderProc;
    
    // this probably shouldn't be NULL
    m_renderProc.inputProcRefCon = NULL;
    
    // allocate info
    m_info = new ModuleAudioUnitInfo();
    
    // set the desired data format
    m_info->m_dataFormat.mSampleRate = srate;
    m_info->m_dataFormat.mFormatID = kAudioFormatLinearPCM;
    m_info->m_dataFormat.mChannelsPerFrame = numChannels;
    m_info->m_dataFormat.mBitsPerChannel = 32;
    m_info->m_dataFormat.mBytesPerPacket = m_info->m_dataFormat.mBytesPerFrame = m_info->m_dataFormat.mChannelsPerFrame * sizeof(SInt32);
    m_info->m_dataFormat.mFramesPerPacket = 1;
    m_info->m_dataFormat.mReserved = 0;
    m_info->m_dataFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger;
    m_info->m_done = 0;
    
    // bound parameters
    if(frameSize > m_info->m_bufferSize)
    {
        frameSize = m_info->m_bufferSize;
    }
    
    // copy parameters
    m_srate = srate;
    m_frameSize = frameSize;
    m_numChannels = numChannels;
    
    // return status code
    OSStatus err;
    
    // initialize and configure the audio session
    err = AudioSessionInitialize(NULL, NULL, rioInterruptionListener, m_au);
    
    if(err)
    {
        // TODO: 'couldn't initialize audio session'
        NSLog(@"error = AudioSessionInitialize");
    }
    
    UInt32 category = kAudioSessionCategory_PlayAndRecord;
    
    // set audio category
    err = AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(category), &category);
    
    if(err)
    {
        // TODO: 'couldn't set audio category'
        NSLog(@"error = couldn't set audio category");
        
        return false;
    }
    
    // MODES
    UInt32 sessionMode;
    
    if(enableBuiltInAEC == true)
    {
        sessionMode = kAudioSessionMode_VoiceChat;
    }
    else
    {
        sessionMode = kAudioSessionMode_Default;
    }
    
    UInt32 propSize;
    AudioSessionGetPropertySize(kAudioSessionProperty_Mode, &propSize);
    AudioSessionSetProperty(kAudioSessionProperty_Mode, propSize, &sessionMode);
    
    // set property listener
    err = AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, propListener, NULL);
    
    if(err)
    {
        // couldn't set property listener
        NSLog(@"error = couldn't set property listener");
        
        return false;
    }
    
    // check for >= OS 2.1
    {
        // chack for headset
        // don't override if headset is plugged in
        
        // get route
        CFStringRef route;
        UInt32 size = sizeof(CFStringRef);
        
        err = AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &size, &route);
        
        if(err)
        {
            // couldn't get new audio route
        }
        
        UInt32 override;
        
        CFRange range = CFStringFind(route, CFSTR("Headset"), 0);
        
        if(range.location != kCFNotFound)
        {
            override = kAudioSessionOverrideAudioRoute_None;
        }
        else
        {
            range = CFStringFind(route, CFSTR("Headphone"), 0);
            if(range.location != kCFNotFound)
            {
                override = kAudioSessionOverrideAudioRoute_None;
            }
            else
            {
                override = kAudioSessionOverrideAudioRoute_Speaker;
            }
        }
        
        // set speaker override
        err = AudioSessionSetProperty(kAudioSessionProperty_OverrideAudioRoute, sizeof(override), &override);
        if(err)
        {
            // couldn't get new audio route
            NSLog(@"error = couldn't set new audio route");
            
            return false;
        }
    }
    
    // compute durations
    Float32 preferredBufferSize = (Float32)(frameSize / srate);
    
    // set sample rate
    AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareSampleRate, sizeof(preferredBufferSize), &preferredBufferSize);
    
    if(err)
    {
        NSLog(@"error = couldn't set preferred sample rate");
        return false;
    }
    
    UInt32 size = sizeof(ModuleAudio::m_hwSampleRate);
    
    // get sample rate
    err=  AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate, &size, &ModuleAudio::m_hwSampleRate);
    
    if(err)
    {
        NSLog(@"error = couldn't get hw sample rate");
        return false;
    }
    
    // set up remote I/O
    bool result;
    if(enableBuiltInAEC == true)
    {
        result = setupRemoteIO(m_au, m_renderProc, m_info->m_dataFormat, kAudioUnitSubType_VoiceProcessingIO);
    }
    else
    {
        result = setupRemoteIO(m_au, m_renderProc, m_info->m_dataFormat, kAudioUnitSubType_RemoteIO);
    }
    
    if(!result)
    {
        NSLog(@"error = couldn't setup remote i/o unit");
        return false;
    }
    
    // initialize buffer
    m_info->m_ioBuffer = new Float32[m_info->m_bufferSize * m_numChannels];
    
    // make sure
    if(!m_info->m_ioBuffer)
    {
        NSLog(@"error = couldn't allocate memory for I/O buffer");
        return false;
    }
    
    // check audio input
    checkInput();
    
    // done with initialization
    m_hasInit = true;
    
    return true;
}


// start() -- start the ModuleAudio
bool ModuleAudio::isRunning(){
    return m_isRunning;
}

bool ModuleAudio::start(ModuleCallback callback, void *bindle)
{
    // assert
    assert(callback != NULL);
    
    // sanity check
    if(!m_hasInit)
    {
        return false;
    }
    
    // sanity check 2
    if(m_isRunning)
    {
        return false;
    }
    
    // remember the callback
    m_callback = callback;
    
    // remember the bindle
    m_bindle = bindle;
    
    // status code
    OSStatus err;
    
    // start audio unit
    err = AudioOutputUnitStart(m_au);
    
    if(err)
    {
        return false;
    }
    
    m_isRunning = true;
    
    return true;
}

// stop() -- stop the ModuleAudio
void ModuleAudio::stop()
{
    // sanity check
    if(!m_isRunning)
    {
        return;
    }
    
    // statuc code
    OSStatus err;
    
    // stop audio unit
    err = AudioOutputUnitStop(m_au);
    
    // flag
    m_isRunning = false;
}

// shutdown() -- shutdiwn the ModuleAudio
void ModuleAudio::shutdown()
{
    AudioSessionRemovePropertyListenerWithUserData(kAudioSessionProperty_AudioRouteChange, propListener, NULL);
    
    // sanity check
    if(!m_hasInit)
    {
        return;
    }
    
    // stop
    stop();
    
    // flag
    m_hasInit = false;
    
    // clear the callback
    m_callback = NULL;
    
    // clean up
    SAFE_DELETE(m_info);
        
}

// checkInput() -- check audio input and sets appropriate flag
void ModuleAudio::checkInput()
{
    // handle input in callback
    m_handleInput = true;
    
    UInt32 has_input;
    UInt32 size = sizeof(has_input);
    
    // get property
    OSStatus err = AudioSessionGetProperty(kAudioSessionProperty_AudioInputAvailable, &size, &has_input);
    
    if(err)
    {
        // TODO: 'warning: unable to determine availability of audio input'
    }
    else if (!has_input)
    {
        // TODO: 'warning: full duplex enabled without available input'
        m_handleInput = false;
    }
}

// vibrate() -- trigger vibration
void ModuleAudio::vibrate()
{
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}

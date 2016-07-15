//
//  module_audio.h
//  recognizer
//
//  Created by 이승희 on 7/14/16.
//  Copyright © 2016 이승희. All rights reserved.
//

#ifndef module_audio_h
#define module_audio_h

// headers
#include "module_info.h"
#include <AudioUnit/AudioUnit.h>

// audio callback function
typedef void (* ModuleCallback)( Float32 * buffer, UInt32 numFrames, void * userData );

// manage information needed by audio unit
struct ModuleAudioUnitInfo
{
    AudioStreamBasicDescription     m_dataFormat;
    UInt32                          m_bufferSize; // # of frames
    UInt32                          m_bufferByteSize;
    Float32                         *m_ioBuffer;
    bool                            m_done;
    
    // constructor
    ModuleAudioUnitInfo()
    {
        m_bufferSize = 4096;
        m_bufferByteSize = 0;
        m_ioBuffer = NULL;
        m_done = false;
    }
    
    //desctructor
    ~ModuleAudioUnitInfo()
    {
        m_bufferSize = 4096;
        m_bufferByteSize = 0;
        SAFE_DELETE_ARRAY( m_ioBuffer );
    }
};

// audio API
class ModuleAudio
{
public:
    static bool init( Float64 srate, UInt32 frameSize, UInt32 numChannels, bool enableBuiltInAEC );
    static bool start( ModuleCallback callback, void *bindle);
    static void stop();
    static void shutdown();
    static Float64 getSampleRate() { return m_srate; };
    static void vibrate();
    
// sketchy public
public:
    static void checkInput();
 
protected:
    static bool initIn();
    static bool initOut();
    
protected:
    static bool m_hasInit;
    static bool m_isRunning;
    
public:
    static ModuleAudioUnitInfo * m_info;
    static ModuleCallback m_callback;
    static AudioUnit m_au;
    static bool     m_isMute;
    static bool     m_handleInput;
    static Float64  m_hwSampleRate;
    static Float64  m_srate;
    static UInt32   m_frameSize;
    static UInt32   m_numChannels;
    static void     *m_bindle;
    
    static bool builtIntAEC_Enabled;
    static bool isRunning();
    
    // audio unit remote I/O
    static AURenderCallbackStruct m_renderProc;
};



#endif /* module_audio_h */

//
//  ViewController.m
//  recognizer
//
//  Created by 이승희 on 7/14/16.
//  Copyright © 2016 이승희. All rights reserved.
//

#import "ViewController.h"
#import "module_audio.h" // stuff that helps set up low-level audio
#import "FFTHelper.h"

#define SAMPLE_RATE     44100
#define FRAMESIZE       512
#define NUMCHANNELS     2
#define kOutputBus      0
#define kInputBus       1

// Nyquist Maximum Frequency
const Float32 NyquistMaxFreq = SAMPLE_RATE / 2.0;

// calculates Hz value for specifed index from a fFT bins vector
Float32 frequencyHzValue(long frequencyIndex ,long fftVectoreSize, Float32 nyquistFrequency)
{
    return ((Float32)frequencyIndex / (Float32)fftVectoreSize) * nyquistFrequency;
}

// the main FFT helper
FFTHelperRef    *fftConverter = NULL;

// accumulator buffer
const UInt32    accumulatorDataLength = 131072;
UInt32          accumulatorFillIndex = 0;
Float32         *dataAccumulator = nil;

static void initializeAccumulator()
{
    dataAccumulator = (Float32 *) malloc(sizeof(Float32) * accumulatorDataLength);
    accumulatorFillIndex = 0;
}

static void destroyAccumulator()
{
    if(dataAccumulator != NULL)
    {
        free(dataAccumulator);
        dataAccumulator = NULL;
    }
    
    accumulatorFillIndex = 0;
}

static BOOL accumulateFrames(Float32 *frames, UInt32 length)
{
    // returned YES if full, NO otherwise
    if(accumulatorFillIndex >= accumulatorDataLength)
    {
        return YES;
    }
    else
    {
        memmove(dataAccumulator + accumulatorFillIndex, frames, sizeof(Float32) * length);
        accumulatorFillIndex = accumulatorFillIndex + length;
        
        if(accumulatorFillIndex >= accumulatorDataLength)
        {
            return YES;
        }
    }
    
    return NO;
}

static void emptyAccumulator()
{
    accumulatorFillIndex = 0;
    memset(dataAccumulator, 0, sizeof(Float32) * accumulatorDataLength);
}

// window buffer
const UInt32    windowLength = accumulatorDataLength;
Float32         *windowBuffer = NULL;

// max value from vector with value index -- using Accelerate Framework
static Float32 vectorMaxValueACC32_index(Float32 *vector, unsigned long size, long step, unsigned long *outIndex)
{
    Float32 maxVal;
    vDSP_maxvi(vector, step, &maxVal, outIndex, size);
    
    return maxVal;
}

// returns Hz of the strongest frequency
static Float32 strongestFrequencyHz(Float32 *buffer, FFTHelperRef *fftHelper, UInt32 frameSize, Float32 *freqValue)
{
    // the actual FFT happens here
    Float32 *fftData = computeFFT(fftHelper, buffer, frameSize);
    
    fftData[0] = 0.0;
    unsigned long length = frameSize / 2.0;
    
    Float32 max = 0;
    unsigned long maxIndex = 0;
    
    max = vectorMaxValueACC32_index(fftData, length, 1, &maxIndex);
    
    if(freqValue != NULL)
    {
        *freqValue = max;
    }
    
    Float32 Hz = frequencyHzValue(maxIndex, length, NyquistMaxFreq);
    
    return Hz;
}

__weak UILabel *labelToUpdate = nil;

//#pragma mark MAIN CALLBACK
void AudioCallback(Float32 *buffer, UInt32 frameSize, void *userData)
{
    // take only data from 1 channel
    Float32 zero = 0.0;
    vDSP_vsadd(buffer, 2, &zero, buffer, 1, frameSize * NUMCHANNELS);
    
    if(accumulateFrames(buffer, frameSize) == YES)
    {
        // if full
        // windowing the time domain data before FFT -- using Blackman window
        if(windowBuffer == NULL)
        {
            windowBuffer = (Float32 *) malloc(sizeof(Float32) * windowLength);
        }
        
        vDSP_blkman_window(windowBuffer, windowLength, 0);
        vDSP_vmul(dataAccumulator, 1, windowBuffer, 1, dataAccumulator, 1, accumulatorDataLength);
        
        
        Float32 maxHzValue = 0;
        Float32 maxHz = strongestFrequencyHz(dataAccumulator, fftConverter, accumulatorDataLength, &maxHzValue);
        
        NSLog(@"max Hz = %0.3f", maxHz);
        dispatch_async(dispatch_get_main_queue(), ^{
            // update UI only on main thread
            labelToUpdate.text = [NSString stringWithFormat:@"%0.3f HZ", maxHz];
        });
        
        // empty the accumulator when finished
        emptyAccumulator();
    }
    
    memset(buffer, 0, sizeof(Float32) * frameSize * NUMCHANNELS);
}

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    labelToUpdate = HzValueLabel;
    
    // initialize stuff
    fftConverter = FFTHelperCreate(accumulatorDataLength);
    initializeAccumulator();
    
    [self initModuleAudio];
}

-(void)initModuleAudio {
    bool result = false;
    result = ModuleAudio::init(SAMPLE_RATE, FRAMESIZE, NUMCHANNELS, false);
    if(!result)
    {
        NSLog(@"ModuleAudio init ERROR");
    }
    
    result = ModuleAudio::start(AudioCallback, NULL);
    if(!result)
    {
        NSLog(@"ModuleAudio start ERROR");
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

-(void) dealloc {
    destroyAccumulator();
    FFTHelperRelease(fftConverter);
}

@end

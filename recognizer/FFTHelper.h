//
//  FFTHelper.hpp
//  recognizer
//
//  Created by 이승희 on 7/15/16.
//  Copyright © 2016 이승희. All rights reserved.
//

#ifndef FFTHelper_h
#define FFTHelper_h

#import <Accelerate/Accelerate.h>
#include <MacTypes.h>

typedef struct FFTHelperRef
{
    FFTSetup        fftSetup;
    COMPLEX_SPLIT   complexA;
    Float32         *outFFTData;
    Float32         *invertedCheckData;
} FFTHelperRef;

FFTHelperRef    *FFTHelperCreate(long numberOfSamples);
Float32         *computeFFT(FFTHelperRef *fftHelperRef, Float32 *timeDomainData, long numSamples);
void            FFTHelperRelease(FFTHelperRef *fftHelper);

#endif /* FFTHelper_h */

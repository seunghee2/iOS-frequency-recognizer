//
//  module_info.h
//  recognizer
//
//  Created by 이승희 on 7/14/16.
//  Copyright © 2016 이승희. All rights reserved.
//

#ifndef module_info_h
#define module_info_h

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

// pi
#define ONE_PI  (3.14159265358979323846)
#define TWO_PI  (2.0 * ONE_PI)
#define SQRT2   (1.41421356237309504880)
#define PI_OVER_180 (ONE_PI / 180.0)

// safe object deletion
#define SAFE_DELETE(x) { delete x; x = NULL; }
#define SAFE_DELETE_ARRAY(x) { delete [] x; x = NULL; }

#ifndef SAMPLE
#define SAMPLE Float32
#endif

#endif /* module_info_h */



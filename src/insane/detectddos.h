/*
 * Copyright (c) 2019 Land-COPPE-UFRJ
 */

#ifndef DETECTDDOS_H_
#define DETECTDDOS_H_

#include <stdbool.h>
#include <stdlib.h>
#include "model.h"

void compute_ratio(double up_samples[NUM_SAMPLES],
                   double down_samples[NUM_SAMPLES],
                   double ratio_samples[NUM_SAMPLES]);
void compute_statistics(double samples[NUM_SAMPLES], double features[3]);
bool read_features(double features[NUM_FEATURES]);

#endif	// DETECTDDOS_H_

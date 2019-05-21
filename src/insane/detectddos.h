/*
 * Copyright (c) 2019 Land-COPPE-UFRJ
 */

#ifndef DETECTDDOS_H_
#define DETECTDDOS_H_

#include <stdbool.h>
#include <stdlib.h>
#include "model.h"

void compute_ratio(float up_samples[NUM_SAMPLES],
                   float down_samples[NUM_SAMPLES],
                   float ratio_samples[NUM_SAMPLES]);
void compute_statistics(float samples[NUM_SAMPLES], float features[3]);
bool read_features(float features[NUM_FEATURES]);

#endif	// DETECTDDOS_H_

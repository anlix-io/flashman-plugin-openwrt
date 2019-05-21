/*
 * Copyright (c) 2019 Land-COPPE-UFRJ
 */

#ifndef OWRTAPI_H_
#define OWRTAPI_H_

#include <stdlib.h>
#include <stdbool.h>
#include "model.h"

bool read_samples(float up_bps_samples[], float up_pps_samples[],
                  float down_bps_samples[], float down_pps_samples[],
                  size_t num_samples);

#endif	// OWRTAPI_H_

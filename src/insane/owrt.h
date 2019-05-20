/*
 * Copyright (c) 2019 Land-COPPE-UFRJ
 */

#ifndef OWRTAPI_H_
#define OWRTAPI_H_

#include <stdlib.h>
#include <stdbool.h>
#include "model.h"

bool read_samples(double up_bps_samples[], double up_pps_samples[],
                  double down_bps_samples[], double down_pps_samples[],
                  size_t num_samples);

#endif	// OWRTAPI_H_

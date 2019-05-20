/*
 * Copyright (c) 2019 Land-COPPE-UFRJ
 */

#include "detectddos.h"

#include <stdio.h>
#include <math.h>
#include "owrt.h"

#define EPSILON 0.0001

void compute_ratio(double up_samples[NUM_SAMPLES],
                   double down_samples[NUM_SAMPLES],
                   double ratio_samples[NUM_SAMPLES]) {
  for (int i = 0; i < NUM_SAMPLES; i++) {
    ratio_samples[i] = (up_samples[i] + EPSILON) / (down_samples[i] + EPSILON);
  }
}

void compute_statistics(double samples[NUM_SAMPLES], double features[3]) {
  double sum = 0.0, mean, var = 0.0;
  double max = samples[0], min = samples[0];

  for (int i = 0; i < NUM_SAMPLES; i++) {
    sum += samples[i];
    if (samples[i] > max) max = samples[i];
    if (samples[i] < min) min = samples[i];
  }
  mean = sum / NUM_SAMPLES;

  for (int i = 0; i < NUM_SAMPLES; i++) {
    var += pow(samples[i] - mean, 2);
  }
  var /= NUM_SAMPLES - 1;

  features[0] = sqrt(var);
  features[1] = max;
  features[2] = max - min;
}

bool read_features(double features[NUM_FEATURES]) {
  double up_bps_samples[NUM_SAMPLES];
  double up_pps_samples[NUM_SAMPLES];
  double down_bps_samples[NUM_SAMPLES];
  double down_pps_samples[NUM_SAMPLES];

  if (read_samples(up_bps_samples, up_pps_samples, down_bps_samples,
                   down_pps_samples, NUM_SAMPLES)) {
    double ratio_bps_samples[NUM_SAMPLES];
    double ratio_pps_samples[NUM_SAMPLES];

    compute_ratio(up_bps_samples, down_bps_samples, ratio_bps_samples);
    compute_ratio(up_pps_samples, down_pps_samples, ratio_pps_samples);

    compute_statistics(up_bps_samples, features);
    compute_statistics(up_pps_samples, features + (NUM_FEATURES / 4));
    compute_statistics(ratio_bps_samples, features + (NUM_FEATURES / 4 * 2));
    compute_statistics(ratio_pps_samples, features + (NUM_FEATURES / 4 * 3));

    return true;
  }
  return false;
}

int main(int argc, char **argv) {
  double features[NUM_FEATURES];

  if (read_features(features)) {
    // printf("%d", predict(features));
    return 0;
  }

  return -1;
}

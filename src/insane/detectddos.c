/*
 * Copyright (c) 2019 Land-COPPE-UFRJ
 */

#include "detectddos.h"

#include <stdio.h>
#include <math.h>
#include "model.h"
#include "owrt.h"

#define EPSILON 0.0001

void compute_ratio(float up_samples[NUM_SAMPLES],
                   float down_samples[NUM_SAMPLES],
                   float ratio_samples[NUM_SAMPLES]) {
  for (int i = 0; i < NUM_SAMPLES; i++) {
    ratio_samples[i] = (up_samples[i] + EPSILON) / (down_samples[i] + EPSILON);
  }
}

void compute_statistics(float samples[NUM_SAMPLES], float features[3]) {
  float sum = 0.0, mean, var = 0.0;
  float max = samples[0], min = samples[0];

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

bool read_features(float features[NUM_FEATURES]) {
  float up_bps_samples[NUM_SAMPLES];
  float up_pps_samples[NUM_SAMPLES];
  float down_bps_samples[NUM_SAMPLES];
  float down_pps_samples[NUM_SAMPLES];

  if (read_samples(up_bps_samples, up_pps_samples, down_bps_samples,
                   down_pps_samples, NUM_SAMPLES)) {
    float ratio_bps_samples[NUM_SAMPLES];
    float ratio_pps_samples[NUM_SAMPLES];

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
  float features[NUM_FEATURES];

  if (read_features(features)) {
    for (int i = 0; i < NUM_FEATURES; i++) {
      fprintf(stderr, "%f\n", features[i]);
    }
    fprintf(stderr, "\n");
    printf("%d", predict(features));
    return 0;
  }

  printf("-1");
  return -1;
}

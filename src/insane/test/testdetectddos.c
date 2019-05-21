/*
 * Copyright (c) 2019 Land-COPPE-UFRJ
 */

#include "detectddos.h"

#include <stdio.h>
#include <math.h>
#include "test/minunit.h"
#include "test/fff.h"

DEFINE_FFF_GLOBALS

int tests_run = 0;

FAKE_VALUE_FUNC(bool, read_samples, float*, float*, float*, float*, size_t);

static bool compare(float expected, float real) {
  float tol = 0.000001;
  return fabs(expected - real) < tol;
}

static char * test_compute_ratio() {
  float up_samples[] = {1.0, 55.9, 99999.0, 0.0, 0.0};
  float down_samples[] = {0.0, 55.9 * 2, 1.0, 1.0, 0.0};
  float ratio[NUM_SAMPLES];
  compute_ratio(up_samples, down_samples, ratio);

  mu_assert("error, ratio[0] != 10001.0", compare(10001.0, ratio[0]));
  mu_assert("error, ratio[1] != 0.500000", compare(0.500000, ratio[1]));
  mu_assert("error, ratio[2] != 99989.0012", compare(99989.0012, ratio[2]));
  mu_assert("error, ratio[3] != 0.000099990001",
            compare(0.000099990001, ratio[3]));
  mu_assert("error, ratio[4] != 1.0", compare(1.0, ratio[4]));
  return 0;
}

static char * test_compute_statistics_equal() {
  float samples[] = {1234.0, 1234.0, 1234.0, 1234.0, 1234.0};
  float features[3];
  compute_statistics(samples, features);

  mu_assert("error, stdev != 0.0    ", compare(0.0, features[0]));
  mu_assert("error, max != 1234.0   ", compare(1234.0, features[1]));
  mu_assert("error, max - min != 0.0", compare(0.0, features[2]));
  return 0;
}

static char * test_compute_statistics_diff() {
  float samples[] = {1515.72099417, 4295.57757286, 12790.35684839,
                      14596.05837595, 13093.47472544};
  float features[3];
  compute_statistics(samples, features);

  mu_assert("error, stdev != 5921.3976130",
            compare(5921.3976130, features[0]));
  mu_assert("error, max != 14596.05837595",
            compare(14596.05837595, features[1]));
  mu_assert("error, max - min != 13080.33738177",
            compare(13080.33738177, features[2]));
  return 0;
}

static char * test_read_features() {
  bool read_samples_custom_fake(float* up_bps_samples, float* up_pps_samples,
      float* down_bps_samples, float* down_pps_samples, size_t num_samples) {
    up_bps_samples[0] = 40640.0;
    up_bps_samples[1] = 22057944.0;
    up_bps_samples[2] = 23402294.0;
    up_bps_samples[3] = 14739795.0;
    up_bps_samples[4] = 29976.0;

    up_pps_samples[0] = 61.0;
    up_pps_samples[1] = 1981.083374;
    up_pps_samples[2] = 2102.133301;
    up_pps_samples[3] = 1339.666626;
    up_pps_samples[4] = 52.000000;

    down_bps_samples[0] = 73072.0;
    down_bps_samples[1] = 59704.0;
    down_bps_samples[2] = 73504.0;
    down_bps_samples[3] = 55200.0;
    down_bps_samples[4] = 64544.0;

    down_pps_samples[0] = 51.0;
    down_pps_samples[1] = 55.0;
    down_pps_samples[2] = 50.0;
    down_pps_samples[3] = 53.0;
    down_pps_samples[4] = 45.0;

    return true;
  }
  read_samples_fake.custom_fake = read_samples_custom_fake;

  float features[NUM_FEATURES];

  mu_assert("error, read_features returned false", read_features(features));
  mu_assert("error, feature[0] != 11456157.0629676",
            compare(11456157.0629676, features[0]));
  mu_assert("error, feature[1] != 23402294.0",
            compare(23402294.0, features[1]));
  mu_assert("error, feature[2] != 23372318.0",
            compare(23372318.0, features[2]));
  mu_assert("error, feature[3] != 1001.946434979",
            compare(1001.946434979, features[3]));
  mu_assert("error, feature[4] != 2102.1333", compare(2102.1333, features[4]));
  mu_assert("error, feature[5] != 2050.1333", compare(2050.1333, features[5]));
  mu_assert("error, feature[6] != 177.7811338009",
            compare(177.7811338009, features[6]));
  mu_assert("error, feature[7] != 369.45504427",
            compare(369.45504427, features[7]));
  mu_assert("error, feature[8] != 368.99061690",
            compare(368.99061690, features[8]));
  mu_assert("error, feature[9] != 19.187052", compare(19.187052, features[9]));
  mu_assert("error, feature[10] != 42.042583",
            compare(42.042583, features[10]));
  mu_assert("error, feature[11] != 40.887028",
            compare(40.887028, features[11]));
  return 0;
}

static char * all_tests() {
  mu_run_test(test_compute_ratio);
  mu_run_test(test_compute_statistics_equal);
  mu_run_test(test_compute_statistics_diff);
  mu_run_test(test_read_features);
  return 0;
}

int main(int argc, char **argv) {
  char *result = all_tests();
  if (result != 0) {
      printf("%s\n", result);
  }
  else {
      printf("ALL TESTS PASSED\n");
  }
  printf("Tests run: %d\n", tests_run);

  return result != 0;
}

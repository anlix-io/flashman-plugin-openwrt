/*
 * Copyright (c) 2019 Land-COPPE-UFRJ
 *
 * Copyright (C) 2010 Jo-Philipp Wich <jow@openwrt.org>
 */

#include "owrt.h"

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

#define IF_SCAN_PATTERN \
        " %[^ :]:%u %u" \
        " %*d %*d %*d %*d %*d %*d" \
        " %u %u"

#define DB_IF_FILE "/tmp/if.data"


struct traffic_entry {
  uint32_t time;
  uint32_t upb;
  uint32_t upp;
  uint32_t downb;
  uint32_t downp;
};

static bool read_network_info(uint32_t* upb, uint32_t* upp, uint32_t* downb,
                              uint32_t* downp) {
  FILE *info;
  char line[1024];
  char ifname[16];

  if ((info = fopen("/proc/net/dev", "r")) != NULL) {
    while (fgets(line, sizeof(line), info)) {
      if (strchr(line, '|')) continue;

      if (sscanf(line, IF_SCAN_PATTERN, ifname, upb, upp, downb, downp)) {
        if (strncmp(ifname, "br-lan", sizeof(ifname)) == 0) {
          fclose(info);
          return true;
        }
      }
    }
    fclose(info);
  }
  return false;
}

static bool init_file(size_t num_rows) {
  struct stat s;
  int file;
  char buf[sizeof(struct traffic_entry)] = { 0 };

  if (stat(DB_IF_FILE, &s) == -1) {
    if ((file = open(DB_IF_FILE, O_WRONLY | O_CREAT, 0600)) == -1) {
      fprintf(stderr, "Failed to init %s: %s\n", DB_IF_FILE, strerror(errno));
      return false;
    }

    for (int i = 0; i < num_rows; i++) {
      if (write(file, buf, sizeof(struct traffic_entry)) < 0) break;
    }
    close(file);
  }

  return true;
}

static bool update_file(struct traffic_entry* entry, size_t num_rows) {
  int file;
  char *map;
  int esize = sizeof(struct traffic_entry);

  if ((file = open(DB_IF_FILE, O_RDWR)) >= 0) {
    map = mmap(NULL, esize * num_rows, PROT_READ | PROT_WRITE,
           MAP_SHARED | MAP_LOCKED, file, 0);

    if ((map != NULL) && (map != MAP_FAILED)) {
      memmove(map, map + esize, esize * (num_rows - 1));
      memcpy(map + esize * (num_rows - 1), entry, esize);
      munmap(map, esize * num_rows);

      close(file);
      return true;
    }

    close(file);
  }

  return false;
}

static bool collect_new_sample(size_t num_rows) {
  uint32_t upb, upp, downb, downp;

  if (read_network_info(&upb, &upp, &downb, &downp)) {
    struct stat s;
    struct traffic_entry e;

    if (init_file(num_rows)) {
      e.time = time(NULL);
      e.upb  = upb;
      e.upp  = upp;
      e.downb  = downb;
      e.downp  = downp;

      return update_file(&e, num_rows);
    }
  }

  return false;
}

bool read_samples(double up_bps_samples[], double up_pps_samples[],
                  double down_bps_samples[], double down_pps_samples[],
                  size_t num_samples) {

  size_t num_rows = num_samples + 1;
  struct traffic_entry* entries[num_rows];
  int fd, size;
  char* map;
  int esize = sizeof(struct traffic_entry);

  if (!collect_new_sample(num_rows)) {
    fprintf(stderr, "Failed to read new sample\n");
  }

  if ((fd = open(DB_IF_FILE, O_RDONLY)) >= 0) {
    size = num_rows * esize;
    map = mmap(NULL, size, PROT_READ, MAP_SHARED | MAP_LOCKED, fd, 0);

    if ((map != NULL) && (map != MAP_FAILED)) {
      for (int i = num_rows - 1; i >= 0; i--) {
        entries[i] = (struct traffic_entry *) &map[i * esize];
        if (!entries[i]->time) {
          fprintf(stderr, "Not enough samples: %d\n", (int) num_rows - i - 1);
          return false;
        }
      }

      for (int i = 0; i < num_rows - 1; i++) {
        double time_delta = entries[i + 1]->time - entries[i]->time;

        up_bps_samples[i] = (entries[i + 1]->upb - entries[i]->upb) * 8;
        up_bps_samples[i] /= time_delta;

        up_pps_samples[i] = entries[i + 1]->upp - entries[i]->upp;
        up_pps_samples[i] /= time_delta;

        down_bps_samples[i] = (entries[i + 1]->downb - entries[i]->downb) * 8;
        down_bps_samples[i] /= time_delta;

        down_pps_samples[i] = entries[i + 1]->downp - entries[i]->downp;
        down_pps_samples[i] /= time_delta;
      }
      return true;
    }
  }

  fprintf(stderr, "Failed to open %s: %s\n", DB_IF_FILE, strerror(errno));
  return false;
}

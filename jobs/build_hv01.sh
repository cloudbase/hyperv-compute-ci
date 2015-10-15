#!/bin/bash
#

# Loading all the needed functions
source /usr/local/src/hyperv-compute-ci/jobs/library.sh

# building hv01
join_hyperv $hyperv01 $WIN_USER $WIN_PASS

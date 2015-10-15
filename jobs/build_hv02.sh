#!/bin/bash
#

# Loading all the needed functions
source /usr/local/src/hyperv-compute-ci/jobs/library.sh

# building hv02
join_hyperv $hyperv02 $WIN_USER $WIN_PASS

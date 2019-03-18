# coding: utf-8


"""Build configuration parameters.

Those can be edited by the user to customize/configure the build system.
"""


from typing import Tuple
from pathlib import Path

from buildchain import ROOT


# Project name.
PROJECT_NAME : str = 'MetalK8s'

# Path to the root of the build directory.
BUILD_ROOT : Path = ROOT/'_build'

# Vagrant configuration.
VAGRANT : str = 'vagrant'
VAGRANT_PROVIDER : str = 'virtualbox'
VAGRANT_UP_OPTS : Tuple[str, ...] = (
    '--provision',
    '--no-destroy-on-error',
    '--parallel',
    '--provider', VAGRANT_PROVIDER
)

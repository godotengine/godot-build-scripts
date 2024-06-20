#!/usr/bin/python3

import argparse
import logging
import os
import sys

from builder import GitRunner, PodmanRunner, ImageConfigs, BuildConfigs
from builder.cli import CLI


if __name__ == "__main__":
    logging.basicConfig(level=logging.DEBUG)
    pwd = os.path.dirname(os.path.realpath(__file__))
    cli = CLI(pwd)
    cli.execute()

#!/usr/bin/env python

PACKAGE_NAME="bofh.contract"
PACKAGE_ROOT="bofh.contract"
PACKAGE_URL="nntp://alt.2600"
VERSION="0.1.2"
DESCRIPTION="The BOfH EVM Contracts package"
AUTHOR_NAME="neta"
AUTHOR_EMAIL="neta@logn.info"
#TEST_SUITE="tests"

CLASSIFIERS = [
    "Development Status :: 2 - Pre-Alpha",
    "Intended Audience :: Developers",
    "License :: Other/Proprietary License",
    "Operating System :: OS Independent",
    "Programming Language :: Python :: 3.8",
    "Programming Language :: Python :: 3.9",
    "Programming Language :: Python :: 3.10",
    "Programming Language :: Python :: Implementation :: CPython",
]
ENTRY_POINTS={
}

from setuptools import setup, find_packages
import sys, os

from setuptools.command.test import test as TestCommand
from distutils.core import Command

here = os.path.dirname(os.path.realpath(__file__))

INSTALL_REQUIRES = list(open(os.path.join(here, "requirements.txt")))

class CleanCommand(Command):
    description = "Clean leftovers of previous builds, tox and test runs"
    user_options = []

    def initialize_options(self):
        self.cwd = None

    def finalize_options(self):
        self.cwd = os.getcwd()

    def run(self):
        assert os.getcwd() == self.cwd, 'Must be in package root: %s' % self.cwd
        os.system("rm -fr "
                  ".eggs "
                  ".tox "
                  "build "
                  "dist "
                  ".coverage htmlcov "
                  "*.egg-info setuptools-*.egg setuptools-*.zip")
        os.system('find . -name __pycache__ '
                  '-o -name \\*.pyc '
                  '-o -name \\*.pyo '
                  '| xargs rm -fr ')


class TestCoverageCommand(Command):
    description = "Run the test suite, producing code coverage report"
    user_options = []

    def initialize_options(self):
        pass

    def finalize_options(self):
        pass

    def run(self):
        os.system("coverage run --branch --source=%s setup.py test" % PACKAGE_ROOT)
        os.system("coverage html --directory=htmlcov")
        indexfile = os.path.join("htmlcov", "index.html")
        if os.path.isfile(indexfile):
            local_url = "file:///" + os.path.abspath(indexfile).replace("\\", "/")
            import webbrowser
            webbrowser.open(local_url)


class ToxCommand(TestCommand):
    description = "Run test suite under Tox, with all supported Python environments"
    user_options = [('tox-args=', 'a', "Arguments to pass to tox")]

    def initialize_options(self):
        TestCommand.initialize_options(self)
        self.tox_args = None

    def finalize_options(self):
        TestCommand.finalize_options(self)
        self.test_args = []
        self.test_suite = True

    def run_tests(self):
        # import here, cause outside the eggs aren't loaded
        import tox
        import shlex
        args = self.tox_args
        if args:
            args = shlex.split(self.tox_args)
        errno = tox.cmdline(args=args)
        sys.exit(errno)


tests_require = []
other_commands = {
    "clean": CleanCommand,
    "coverage": TestCoverageCommand,
    "tox": ToxCommand,
}

if "coverage" in sys.argv:
    tests_require += [
        "coverage",
    ]

if "tox" in sys.argv:
    tests_require += [
        "tox",
        "setuptools",
        "virtualenv",
    ],


def namespace_packages():
    result = []
    toks = PACKAGE_ROOT.split(".")
    for i in range(1, len(toks)):
        result.append(".".join(toks[:i]))
    return result


setup(
    name            = PACKAGE_NAME,
    version         = VERSION,
    description     = DESCRIPTION,
    author          = AUTHOR_NAME,
    author_email    = AUTHOR_EMAIL,
    url             = PACKAGE_URL,
    zip_safe = False, # unnecessary; it avoids egg-as-zipfile install
    packages = find_packages(exclude=['tests']),
    namespace_packages = namespace_packages(),
    install_requires = INSTALL_REQUIRES,
    tests_require = tests_require,
    cmdclass = other_commands,
    classifiers = CLASSIFIERS,
#    test_suite=TEST_SUITE,
    entry_points=ENTRY_POINTS,
)

#!/usr/bin/python
import os
import sys

class CompilerWrapper():
    def __init__(self, argv):
        self.args = argv[1:]
        self.real_compiler = None
        self.argv0 = argv[0]

    def set_real_compiler(self):
        compiler_path = os.path.dirname(os.path.abspath(__file__))
        self.real_compiler = os.path.join(compiler_path, "clang-real_")

    def parse_custom_flags(self):
        if not "-O0" in self.args:
            self.args += ["-O3"]
        if "--target=aarch64-linux-gnu" in self.args:
            self.args += ["-march=armv9-a+crypto+nosve+bf16+fp16fml+i8mm+memtag+pmuv3+profile", "-mtune=cortex-a510"]
        # self.args += ["-mllvm=-polly", "-mllvm=-polly-ast-use-context", "-mllvm=-polly-invariant-load-hoisting", "-mllvm=-polly-loopfusion-greedy", "-mllvm=-polly-run-inliner", "-mllvm=-polly-vectorizer=stripmine", "-mllvm=-polly-run-dce"]
        self.args += ["-Wno-error", "-Wno-unused-command-line-argument"]

    def invoke_compiler(self):
        self.set_real_compiler()
        self.parse_custom_flags()
        execargs = [self.argv0] + self.args
        # with open("/tmp/wrapper-log", "a") as log_file:
        #     log_file.write(' '.join(execargs) + '\n')
        os.execv(self.real_compiler, execargs)


def main(argv):
    cw = CompilerWrapper(argv)
    cw.invoke_compiler()

if __name__ == "__main__":
    main(sys.argv)

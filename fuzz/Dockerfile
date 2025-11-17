# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
################################################################################

FROM gcr.io/oss-fuzz-base/base-builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    make \
    wget \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone the mrustc repository
RUN git clone --depth 1 https://github.com/thepowersgang/mrustc.git $SRC/mrustc

# Set working directory
WORKDIR $SRC/mrustc

# Create fuzz directory and copy fuzzer sources
RUN mkdir -p fuzz
COPY fuzz_lexer.cpp fuzzer_stubs.cpp fuzz/
COPY fuzz_lexer_seed_corpus.zip fuzz_lexer.options fuzz/

# Copy build script to $SRC (required by OSS-Fuzz)
COPY build.sh $SRC/

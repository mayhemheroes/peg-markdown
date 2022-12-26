FROM --platform=linux/amd64 ubuntu:20.04 as builder

RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential libglib2.0-dev clang

COPY . /repo
WORKDIR /repo
RUN sed -i 's/element \*new/element *n/' /repo/utility_functions.h
RUN make -j8
RUN  clang++ /repo/mayhem/fuzz_mk_str.cpp -fsanitize=fuzzer,address /repo/libpeg-markdown.a -lglib-2.0 -o /fuzz -I /repo/ -I /usr/include/glib-2.0/ -I /usr/lib/x86_64-linux-gnu/glib-2.0/include/ -o /fuzz

FROM ubuntu:20.04 as package
RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y libglib2.0-dev
COPY --from=builder /repo/markdown /
COPY --from=builder /fuzz /fuzz_mk_str

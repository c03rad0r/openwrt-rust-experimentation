# Use the cache image as the base
FROM openwrt-rust-builder:cache


RUN git clone https://github.com/openwrt/openwrt.git
WORKDIR openwrt
RUN ls -la


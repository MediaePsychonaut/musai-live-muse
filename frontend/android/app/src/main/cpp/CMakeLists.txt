cmake_minimum_required(VERSION 3.22.1)

project("oboe_pulse_engine")

find_package(oboe REQUIRED CONFIG)

add_library(
        oboe_pulse_engine
        SHARED
        oboe_pulse_engine.cpp)

target_link_libraries(
        oboe_pulse_engine
        oboe::oboe
        log)

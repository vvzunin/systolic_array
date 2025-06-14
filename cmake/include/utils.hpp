#pragma once
#include <vector>
#include <string>
#include <concepts>
#include <boost/asio.hpp>
#include "imgui_log.hpp"
#include "defines.hpp"

template <std::integral T>
void load_matrix(AppLog &log, std::vector<std::vector<T>> &matrix, std::string &path, bool &loaded) 
{
    int res = CSVReader::read_matrix(matrix, path); 
    if(res > 0) LOG_ERROR(log, LOG_CATEGORY_CSV, std::format("failed to load file {}", path).c_str());
    else loaded = true;
};

template <std::integral T>
void save_matrix(AppLog &log, std::vector<std::vector<T>> &matrix, std::string &path) 
{
    int res = CSVReader::save_matrix(matrix, path); 
    if(res > 0) LOG_ERROR(log, LOG_CATEGORY_CSV, std::format("failed to save to file {}", path).c_str());
};

template <std::integral T>
void form_packet(std::vector<std::vector<T>> &data, std::vector<std::vector<T>> &weights, std::vector<uint8_t> &packet)
{
    packet.clear();

    packet.push_back(START_BYTE);
    packet.push_back(CMD_FETCH_WEIGHTS);

    for(std::vector<T>& row : weights) 
        for(T& el : row) {
            packet.push_back(START_BYTE);
            packet.push_back(CMD_DATA);
            for(int i = 0; i < sizeof(T); ++i) 
                packet.push_back((uint8_t)((el >> (8 * i)) & 0xff));
        }

    
    packet.push_back(START_BYTE);
    packet.push_back(CMD_LOAD_WEIGHTS);


    packet.push_back(START_BYTE);
    packet.push_back(CMD_FETCH_DATA);

    for(std::vector<T>& row : data) 
        for(T& el : row) {
            packet.push_back(START_BYTE);
            packet.push_back(CMD_DATA);
            for(int i = 0; i < sizeof(T); ++i) 
                packet.push_back((uint8_t)((el >> (8 * i)) & 0xff));
        }


    packet.push_back(START_BYTE);
    packet.push_back(CMD_START_COMP);
}
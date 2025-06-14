#pragma once
#include <vector>
#include <iostream>
#include <fstream>
#include <boost/algorithm/string.hpp>

class CSVReader
{
public:
    // CSVReader();

    static int read_matrix(std::vector<std::vector<std::string>> &matrix, std::string path)
    {
        std::ifstream file(path);
        if(!file.is_open()) return 1;

        size_t idx = 0;
        std::string line;
        while(std::getline(file, line)) {
            matrix.push_back({});
            boost::split(matrix[idx], line, boost::is_any_of(",;"));
            ++idx;
        }
        file.close();
        return 0;
    }


    template<std::integral T>
    static int read_matrix(std::vector<std::vector<T>> &matrix, std::string path)
    {
        std::ifstream file(path);
        if(!file.is_open()) return 1;

        matrix.clear();
        size_t idx = 0;
        std::string line;
        std::vector<std::string> row;
        while(std::getline(file, line)) {
            matrix.push_back({});
            boost::split(row, line, boost::is_any_of(",;"));
            for(auto& el : row) {
                int el_int = std::stoi(el);
                matrix[idx].push_back(static_cast<T>(el_int));
            }
            ++idx;
        }
        file.close();
        return 0;
    }

    template<std::integral T>
    static int save_matrix(std::vector<std::vector<T>> &matrix, std::string path)
    {
        std::ofstream file(path, std::ios::out | std::ios::trunc);
        if(!file.is_open()) return 1;

        for(auto& row : matrix) {
            for(auto& el : row) {
                file << el << ",";
            }
            file << "\n";
        }
        file.close();
        return 0;
    }
};
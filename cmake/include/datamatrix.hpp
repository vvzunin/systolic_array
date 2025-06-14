#pragma once
#include <vector>
#include <string>
#include <concepts>

typedef uint32_t data_t;

template <std::integral T>
struct Datamatrix
{
    Datamatrix(std::string _filename = "")
        : loaded{false}, filename{_filename}
    {}

    Datamatrix(size_t width, size_t height, std::string _filename = "")
        : loaded{false}, filename{_filename}, matrix{height, std::vector<T>(width, 0)}
    {}

    void resize(size_t h, size_t w) 
    {
        matrix.resize(h);
        for(std::vector<T>& row : matrix)  row.resize(w); 
    }

    size_t get_h() { if(!matrix.empty()) return matrix.size(); return 0; }
    size_t get_w() { if(!matrix.empty()) if(!matrix.begin()->empty()) return matrix.begin()->size(); return 0; }
    
    bool loaded;
    std::string filename;
    std::vector<std::vector<T>> matrix;
};
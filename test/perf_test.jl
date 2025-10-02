using CDAWeb
using Chairmarks
CDAWeb.get_data("AC_H0_MFI/BGSEc", "2023-01-01", "2023-01-02")

julia> @b CDAWeb.get_data("AC_H0_MFI/BGSEc", "2023-01-01", "2023-01-02")
# 29.250 μs (227 allocs: 10.016 KiB)

@b CDAWeb.get_data("AC_H0_MFI/BGSEc", "2023-01-01", "2023-01-02T01")
# 49.083 μs (383 allocs: 17.156 KiB)
@b CDAWeb.get_data("AC_H0_MFI/BGSEc", "2023-01-01", "2023-01-02T01"; orig=true)
# 49.250 μs (346 allocs: 16.562 KiB)

# julia> @b CDAWeb.get_data("AC_H0_MFI/BGSEc", "2023-01-01", "2023-01-02")
# 24.875 μs (170 allocs: 7.594 KiB)

julia> @b CDAWeb.get_data_files("AC_H0_MFI", "BGSEc", "2023-01-01", "2023-01-02")
# 4.783 μs (87 allocs: 3.422 KiB)
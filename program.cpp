#include <algorithm>
#include <array>
#include <iostream>
#include <vector>

#include <fmt/format.h>
#include <llvm-c/Disassembler.h>
#include <llvm-c/Target.h>

using u8 = std::uint8_t;
using i32 = std::int32_t;
using u32 = std::uint32_t;

void printUsage(auto self) {
    fmt::print("Usage: {} <PC> <thumb/a32/a64> <Instructions (hexadecimal)>\n", self);
    std::exit(EXIT_FAILURE);
}
template <typename ...Args>
void clash(auto self, const std::string& format, Args... args) {
    fmt::print(fmt::runtime(format), std::forward<Args>(args)...);
    printUsage(self);
}

auto collectAllInstructions(const i32 argc, char** argv) {
    std::vector<u32> collection;
    for (i32 index{3}; index < argc; ++index) {
        std::string_view hex{argv[index]};
        if (!hex.starts_with("0x"))
            clash(argv[0], "Invalid instruction format {}\n", hex);
        hex.remove_prefix(2);
        if (hex.size() > 8)
            clash(argv[0], "Invalid instruction size {}\n", hex);
        auto instructionBytes{strtoul(hex.data(), nullptr, 16)};
        collection.emplace_back(instructionBytes);
    }

    return collection;
}

std::array<char, 0xff> buffer{};

std::string disassembleA32(const bool isThumb, const u32 pc, const u32 instruction, u32 size) {
    const auto ctx{LLVMCreateDisasm(isThumb ? "thumbv7" : "armv8-arm", nullptr, 0, nullptr, nullptr)};
    LLVMSetDisasmOptions(ctx, LLVMDisassembler_Option_UseMarkup);

    std::string result;
    while (size) {
        std::array<u8, 0x4> macro{};
        std::memcpy(macro.data(), &instruction, size);

        auto sizeUsed{LLVMDisasmInstruction(ctx, macro.data(), size, pc, buffer.data(), buffer.size())};
        result = sizeUsed > 0 ? buffer.data() : "<invalid>";
        if (!sizeUsed) {
            if (isThumb)
                sizeUsed = 2;
            else
                sizeUsed = 4;
        }
        result += '\n';
        size -= sizeUsed;
    }

    LLVMDisasmDispose(ctx);
    return result;
}

std::string disassembleA64(const u32 pc, const u32 instruction) {
    std::string result;
    const auto ctx{LLVMCreateDisasm("aarch64", nullptr, 0, nullptr, nullptr)};
    LLVMSetDisasmOptions(ctx, LLVMDisassembler_Option_AsmPrinterVariant);

    std::array<u8, 0x4> macro{};
    std::memcpy(macro.data(), &instruction, macro.size());
    if (!LLVMDisasmInstruction(ctx, macro.data(), pc, instruction, buffer.data(), buffer.size())) {
        result = "<invalid>\n";
    } else {
        result = buffer.data();
        result += '\n';
    }
    LLVMDisasmDispose(ctx);
    return result;
}

int main(const i32 argc, char **argv) {
    if (argc < 4)
        printUsage(argv[0]);

    i32 mode{};
    if (std::string_view{argv[2]} == "thumb") {
        mode = 1;
    } else if (std::string_view{argv[2]} == "a32") {
        mode = 2;
    } else if (std::string_view{argv[2]} == "a64") {
        mode = 3;
    }
    if (!mode)
        printUsage(argv[0]);

    auto pc{std::strtol(argv[1], nullptr, 16)};

    // ReSharper disable once CppTooWideScope
    const bool is32{mode != 3};
    if (is32) {
        LLVMInitializeARMTargetInfo();
        LLVMInitializeARMTargetMC();

        LLVMInitializeARMDisassembler();
    } else {
        // aarch64
        LLVMInitializeAArch64TargetInfo();
        LLVMInitializeAArch64TargetMC();
        LLVMInitializeAArch64Disassembler();
    }

    // ReSharper disable once CppTooWideScopeInitStatement
    const auto instructions{collectAllInstructions(argc, argv)};
    for (const auto arm : instructions) {
        u32 size{4};

        switch (mode) {
            case 1:
                size = arm >> 16 == 0 ? 2 : 4;
                fmt::print("{:08x}: {:x} -> {}", pc, arm, disassembleA32(true, pc, arm, size));
                break;
            case 2:
                fmt::print("{:08x}: {:x} -> {}", pc, arm, disassembleA32(false, pc, arm, size));
                break;
            case 3:
                fmt::print("{:08x}: {:x} -> {}", pc, arm, disassembleA64(pc, arm));
                break;
            default:
                clash(argv[0], "Invalid specified mode {}", mode);
        }
        pc += size;
    }

    return EXIT_SUCCESS;
}

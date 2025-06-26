local function lzssd(s)
    local out = ""

    local cursor = 0
    local function read(n)
        local res = s:sub(cursor + 1, cursor + n)
        cursor = cursor + n
        return res
    end

    while cursor < #s do
        local c = read(1)
        if not c then break end

        if c == "\1" then
            local length = read(1):byte()
            local chars = read(length)
            out = out .. chars
        end

        if c == "\2" then
            local offset = read(1):byte()
            local length = read(1):byte()
            local start = #out - offset + 1
            for i = 0, length - 1 do
                out = out .. out:sub(start + (i % offset), start + (i % offset))
            end
        end
    end

    return out
end

local function lzsse(s)
    local out = ""
    local cursor = 1

    while cursor <= #s do
        local offset = 0
        local length = 0

        for i = 1, math.min(255, cursor - 1) do
            local start = cursor - i
            local len = 0

            while cursor + len <= #s and len < 255 do
                local src_pos = start + (len % i)
                if s:sub(cursor + len, cursor + len) ~= s:sub(src_pos, src_pos) then
                    break
                end
                len = len + 1
            end

            if len > length then
                offset = i
                length = len
            end
        end

        if length >= 3 then
            out = out .. "\2" .. string.char(offset) .. string.char(length)
            cursor = cursor + length
        else
            local chars = ""
            local count = 0

            while cursor <= #s and count < 255 do
                local found = false

                for i = 1, math.min(255, cursor - 1) do
                    local start = cursor - i
                    local len = 0

                    while cursor + len <= #s and len < 255 do
                        local src_pos = start + (len % i)
                        if s:sub(cursor + len, cursor + len) ~=
                            s:sub(src_pos, src_pos) then
                            break
                        end
                        len = len + 1
                    end

                    if len >= 3 then
                        found = true
                        break
                    end
                end

                if found and count > 0 then break end

                chars = chars .. s:sub(cursor, cursor)
                count = count + 1
                cursor = cursor + 1
            end

            if count > 0 then
                out = out .. "\1" .. string.char(count) .. chars
            end
        end
    end

    return out
end

local function escape_string(s)
    local result = ""
    for i = 1, #s do
        local c = s:sub(i, i)
        local b = c:byte()
        if b == 1 then
            result = result .. "\\1"
        elseif b == 2 then
            result = result .. "\\2"
        elseif b < 32 or b > 126 then
            result = result .. "\\" .. b
        else
            result = result .. c
        end
    end
    return result
end

local function print_compressed(s)
    local escaped = escape_string(s)
    print("Compressed: " .. escaped)
end

local samples = {
    {"empty", ""}, {"single", "a"}, {"double", "ab"}, {"triple", "abc"},
    {"hello", "hello"}, {"aa", "aa"}, {"aaa", "aaa"}, {"aaaa", "aaaa"},
    {"aaaaa", "aaaaa"}, {"aaaaaa", "aaaaaa"}, {"abcabc", "abcabc"},
    {"abcabcabc", "abcabcabc"}, {"helloworld", "helloworld"},
    {"hellohello", "hellohello"}, {"hellox3", "hellohellohello"},
    {"complex", "hellohehahehaihello"}, {"abcx2", "abcdefghijabcdefghij"},
    {"abcx3", string.rep("abcdefghij", 3)}, {"xylong", string.rep("xy", 50)},
    {"ab128", string.rep("ab", 128)}, {"abc85", string.rep("abc", 85)},
    {"a255", string.rep("a", 255)}, {"a256", string.rep("a", 256)},
    {"a300", string.rep("a", 300)}, {"abcdef50", string.rep("abcdef", 50)},
    {"xa254", "x" .. string.rep("a", 254)},
    {"xa255", "x" .. string.rep("a", 255)},
    {"xa256", "x" .. string.rep("a", 256)},
    {"alphabet", "aabbccddeeffgghhiijjkkllmmnnooppqqrrssttuuvvwwxxyyzz"},
    {"fox", "the quick brown fox jumps over the lazy dog"},
    {"banana", "banana"}, {"banananana", "banananana"},
    {"ablong", string.rep("ab", 30)}, {"test64", string.rep("test", 64)},
    {"azx10", string.rep("abcdefghijklmnopqrstuvwxyz", 10)},
    {"compx20", "compression" .. string.rep("compression", 20)},
    {"digits26", string.rep("1234567890", 26)}, {"mississippi", "mississippi"},
    {
        "aaa100",
        "aaabaaacaaadaaaeaaafaaagaaahaaaiaaajaaakaaalaaamaaanaaaoaaapaaaqaaaraaasaaataaauaaavaaawaaaxaaayaaazaaa"
    }, {"mia", string.rep("mia", 312)}
}

local passed = 0
local total = #samples

print("LZSS Test Results:")
print(string.rep("-", 40))

for i, sample in ipairs(samples) do
    local name, text = sample[1], sample[2]
    local compressed = lzsse(text)
    local decompressed = lzssd(compressed)
    local match = decompressed == text

    if match then passed = passed + 1 end

    local status = match and "PASS" or "FAIL"
    local ratio = #text > 0 and
                      string.format("%.1f%%", (#compressed / #text) * 100) or
                      "0%"

    print(string.format("[%02d] %-12s %s %3d->%3d (%6s)", i, name, status,
                        #text, #compressed, ratio))
end

print(string.rep("-", 40))
print(string.format("Overall: %d/%d passed (%.1f%%)", passed, total,
                    (passed / total) * 100))

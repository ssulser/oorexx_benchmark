/* Internal elapsed times; each line: phase seconds checked-result. */
numeric digits 15
call time 'R'
records = .array~new(200000)
do i = 1 for 200000
    records[i] = 'record-' || right(i - 1, 8, '0') || '-' || copies('x', 32)
end
elapsed = time('E')
say 'records' elapsed records~items

call time 'R'
a = .array~new(200000)
do i = 1 for 200000
    a[i] = records[i]
end
elapsed = time('E')
say 'array_build' elapsed a~items

sum = 0
call time 'R'
do 20
    do value over a
        sum = sum + length(value)
    end
end
elapsed = time('E')
say 'array_scan' elapsed sum

call time 'R'
keys = .array~new(100000)
do i = 1 for 100000
    keys[i] = 'K' || i
end
elapsed = time('E')
say 'keys' elapsed keys~items

call time 'R'
h = .table~new
do i = 1 for 100000
    h~put(i, keys[i])
end
elapsed = time('E')
say 'table_build' elapsed h~items

sum = 0
call time 'R'
do 20
    do key over keys
        sum = sum + h~at(key)
    end
end
elapsed = time('E')
say 'lookup' elapsed sum

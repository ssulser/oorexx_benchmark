/* Isolated stream phases: formatting and validation outside the timer. */
numeric digits 15
parse arg mode path
if path = '' then exit 2
select
    when mode = 'write' then do
        records = .array~new(200000)
        do i = 1 for 200000
            records[i] = 'record-' || right(i, 8, '0') || '-The quick brown fox jumps over the lazy dog'
        end
        call time 'R'
        status = stream(path, 'c', 'open write replace')
        if status <> 'READY:' then exit 2
        do line over records
            if lineout(path, line) <> 0 then exit 2
        end
        status = stream(path, 'c', 'close')
        elapsed = time('E')
        if status <> 'READY:' then exit 2
        say 'io_write' elapsed 12000000 200000
    end
    when mode = 'read' then do
        bytes = 0
        count = 0
        call time 'R'
        status = stream(path, 'c', 'open read')
        if status <> 'READY:' then exit 2
        do while lines(path) > 0
            line = linein(path)
            bytes = bytes + length(line) + 1
            count = count + 1
        end
        status = stream(path, 'c', 'close')
        elapsed = time('E')
        if status <> 'READY:' then exit 2
        say 'io_read' elapsed bytes count
    end
    otherwise exit 2
end

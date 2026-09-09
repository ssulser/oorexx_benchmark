/* ooRexx benchmark */
numeric digits 20

parse arg test path

select
    when test = 'cpu' then do
        sum = 0
        do i = 1 to 5000000
            sum = sum + (i // 97)
        end
        say sum
    end

    when test = 'strings' then do
        source = 'The quick brown fox jumps over the lazy dog 0123456789'
        sum = 0
        do 1000000
            s = translate(source)
            s = substr(s, 6, 20)
            sum = sum + length(s)
        end
        say sum
    end

    when test = 'array' then do
        a = .array~new(200000)

        do i = 1 to 200000
            a[i] = 'record-' || right(i - 1, 8, '0') || '-' || copies('x', 32)
        end

        sum = 0
        do i = 1 to 200000
            sum = sum + length(a[i])
        end
        say sum
    end

    when test = 'lookup' then do
        h = .table~new

        do i = 1 to 100000
            key = 'K' || i
            h~put(i, key)
        end

        sum = 0
        do i = 1 to 2000000
            key = 'K' || ((i // 100000) + 1)
            sum = sum + h~at(key)
        end
        say sum
    end


    when test = 'parse' then do
        line = '4711|Simon Sulser|Winterthur|1975|1234.56'
        sum = 0

        do 1000000
            parse var line id '|' name '|' city '|' year '|' amount
            sum = sum + length(id) + length(name) + length(city) + -
                  length(year) + length(amount)
        end
        say sum
    end

    when test = 'io' then do
        if path = '' then do
            say 'io test requires a path'
            exit 2
        end

        call stream path, 'c', 'open write replace'
        do i = 1 to 200000
            line = 'record-' || right(i, 8, '0') || '-The quick brown fox jumps over the lazy dog'
            call lineout path, line
        end
        call stream path, 'c', 'close'

        sum = 0
        call stream path, 'c', 'open read'
        do while lines(path) > 0
            line = linein(path)
            sum = sum + length(line) + 1
        end
        call stream path, 'c', 'close'
        say sum
    end

    when test = 'noop' then say 'ok'

    otherwise do
        say 'unknown test:' test
        exit 2
    end
end

exit 0

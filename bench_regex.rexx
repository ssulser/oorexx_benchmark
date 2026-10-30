/* ooRexx regular-expression benchmark */

myRE = .RegularExpression~new('[A-Z][A-Z][0-9][0-9][0-9][0-9]-[a-z]+')

good = 'AB4711-winterthur'
bad  = 'A94711-Winterthur'

matches = 0

do i = 1 for 1000000
    if i // 2 = 1 then
        s = good
    else
        s = bad

    if myRE~match(s) then
        matches = matches + 1
end

say matches

::requires 'rxregexp.cls'

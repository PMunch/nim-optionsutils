import  optionsutils, options

proc a(a,b: Option[int], c = 100){.withSome.}= echo a, " ", b, " ", c

proc b(a: Option[int]){.withNone.}= echo "Only Nones Work!"

a(some(10), none(int), 300) #Doesn't Print
a(some(10), some(100)) #Prints 10, 10
b(none(int)) #Prints "Only Nones Work!"
b(some(100)) #Doesnt Print
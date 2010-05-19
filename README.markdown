Ruby Simple Planner
===================

DESCRIPTION
-----------

A simple planner written in Ruby

REQUIREMENTS
------------

 * sudo gem install algorithms

USAGE
-----

        planner.rb <domain> <problem_number>

Example:

    $ ruby1.9 planner.rb blocks 1
    
    Initial distance = 8 .....
      h =  4 ......
      h =  3 ...............
      h =  2 ....
      h =  0 
    SOLUTION: (10 actions)
     unstack(B,A)
     putdown(B)
     pickup(A)
     stack(A,C)
     unstack(A,C)
     putdown(A)
     pickup(C)
     stack(C,B)
     pickup(A)
     stack(A,C)

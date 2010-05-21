Ruby Simple Planner
===================

DESCRIPTION
-----------

A simple planner for [STRIPS](http://en.wikipedia.org/wiki/STRIPS) domains written in Ruby

REQUIREMENTS
------------

        $ sudo gem install algorithms

USAGE
-----

The planner accepts STRIPS domains and problems specified with a YAML syntax. 
In the `domains` directory you find the representations of these problems:

* **blocks** is the [classical problem](http://en.wikipedia.org/wiki/Blocks_world) of stacking blocks on a table surface using a robotic arm
* **hanoi** is the well-known game of the Tower of Hanoi
* **elevator** represents the problem of transporting people between floors of a building.

You can launch the planner specifying a domain and a problem number (currently 1 to 3):

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

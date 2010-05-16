require 'yaml'
require 'heuristic'

module Kernel
  def debug(str)
    #puts str
  end
end

class Problem
  attr_accessor :predicates, :objects, :operators, :initial_state, :goal
  def initialize(values)
    @predicates = values[:predicates]
    @objects = values[:objects]
    @operators = values[:operators]
    @initial_state = values[:initial_state]
    @goal = values[:goal]
    @@instance = self
  end

  def Problem.instance
    @@instance
  end
end

class Predicate
  attr_accessor :name, :parameters

  def initialize(p)
    tokens = p.split
    @name = tokens.shift
    @parameters = tokens
  end

end

class Fact
  attr_reader :predicate, :substitutions
  @@facts = {}

  def initialize(predicate, subst)
    @predicate = predicate
    @substitutions = subst
  end

  def Fact.get_or_create(predicate, subst)
    key = Fact.unique_key(predicate, subst)
    @@facts[key] || @@facts[key] = Fact.new(predicate, subst)
  end

  def Fact.unique_key(predicate, subst)
    predicate.name + "(" + predicate.parameters.map{|e| subst[e]}.join(',') + ")"
  end

  def unique_key
    Fact.unique_key(@predicate, @substitutions)
  end

  def to_s
    if !@unique_key
      @unique_key = unique_key
    end
    @unique_key
  end
  
  def Fact.instances
    @@facts.values
  end

end

class State
  attr_accessor :facts

  def initialize(value, predicates)
    @facts = {}
    value.each do |f|
      tokens = f.split
      predicate = predicates[tokens.shift]
      subst = {}
      predicate.parameters.each{|param| subst[param] = tokens.shift}
      fact = Fact.get_or_create(predicate, subst)
      @facts[fact.unique_key] = fact 
    end
  end
  
  def clone
    s = State.new([], nil)
    s.facts = @facts.dup
    s
  end

  def add_fact(fact)
    @facts[fact.unique_key] = fact
  end

  def delete_fact(fact)
    @facts.delete(fact.unique_key)
  end

  def each_fact(&block)
    @facts.values.each{|v| yield v }
  end

  def include_fact?(fact)
    return @facts.include?(fact.unique_key)
  end

  def to_s
    super.to_s + "\n" + @facts.map{|k,v| v.to_s}.join("\n") + "\n---"
  end

  def apply_action(action)
    debug "Appliyng action #{action}"

    action.operator.effect.each do |effect|
      fact = get_matching_fact(effect, action)
      if effect.split[0].casecmp('not') != 0
        add_fact(fact)
      else
        delete_fact(fact)
      end
    end
    debug "NEW STATE:" + self.to_s
  end

  def find_applicable_actions(ignore_negations = false)
    res = []
    #puts "find_applicable_actions(#{ignore_negations})"
    #puts self
    Problem.instance.operators.each do |operator|
      Planner.comb(Problem.instance.objects, operator.parameters.size).each do |objs|
        subst = {}
        param = Array.new(operator.parameters)
        objs.each{|o| subst[param.shift] = o}
        action = Action.new(operator, subst)
        res << action if is_applicable?(action, ignore_negations)
      end
    end
    
    debug "Applicable actions in state #{self}: "
    debug res
    res
  end
  
  def is_applicable?(action, ignore_negations = false)
    action.operator.precondition.each do |prec|
      f = get_matching_fact(prec, action)
      exists = include_fact?(f)
      negated = (prec.split[0].casecmp('not') == 0)
      next if negated && ignore_negations
      if (exists == negated)
        #puts "Action #{action} is not applicable - failed precondition #{prec}"
        return false
      end
    end
    true
  end

  def get_matching_fact(precondition, action)
    tokens = precondition.split
    if tokens[0].casecmp('not') == 0
      tokens.shift
    end
    predicate = Problem.instance.predicates[tokens[0]]
    subst = {}
    tokens = tokens[1..-1]
    predicate.parameters.each do |p| 
      subst[p] = action.substitutions[tokens.shift] 
    end
    f = Fact.get_or_create(predicate, subst)
  end


end

class Operator
  attr_accessor :name, :parameters, :precondition, :effect

  def initialize(name, value)
    @name = name
    @parameters = value['parameters'].split
    @precondition = value['precondition']
    @effect = value['effect']
  end

end

class Action
  attr_accessor :operator, :substitutions

  def initialize(operator, substitutions)
    @operator = operator
    @substitutions = substitutions
  end

  def to_s
    @operator.name + "(" + @operator.parameters.map{|p| @substitutions[p].to_s}.join(',') + ")"
  end
end

class Planner
  
  def initialize(domain_file, problem_file)

    domain = YAML.load(File.new(domain_file,'r').read)
    predicates = {}
    domain['predicates'].each do |p|
      predicate = Predicate.new(p)
      predicates[predicate.name] = predicate
    end

    operators = []
    domain['actions'].each_pair do |name, value|
      operators << Operator.new(name, value)
    end

    problem = YAML.load(File.new(problem_file, 'r').read)
    objects = problem['objects']
    initial_state = State.new(problem['init'], predicates)
    goal = State.new(problem['goal'], predicates)

    @current_state = initial_state
    @problem = Problem.new(:predicates => predicates,
                :objects => objects,
                :initial_state => initial_state,
                :goal => goal,
                :operators => operators)

    @heuristic = Heuristic.new(@problem)
  end

  def solve
    solution = []
    while !is_goal_satisfied?(@current_state)
      actions = @current_state.find_applicable_actions
      if actions.empty?
        puts "DEAD END."
        exit
      end
      action = choose_best_action(@current_state, actions)
      puts "Executing action #{action}"
      solution << action
      @current_state.apply_action(action)
    end
    puts "SOLUTION LENGTH: #{solution.size}"
    puts solution.join(" ")
  end
  

  
  def choose_best_action(state, actions)
    #actions[rand(actions.size)]
    @heuristic.choose_best_action(@current_state, actions)
  end
  
  def is_goal_satisfied?(state)
    @problem.goal.each_fact do |goal|
      return false if !state.include_fact?(goal)
    end
    true
  end
  
  def Planner.comb(array, n)
    return array.map{|e| [e]} if n == 1
    res = []
    array.each do |e|
      Planner.comb(array, n - 1).each do |f|
        res << [e] + f
      end
    end
   res
  end


end

planner = Planner.new('domain.yml','problem.yml')
planner.solve

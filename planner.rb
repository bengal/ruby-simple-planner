require 'rubygems'
require 'yaml'
require 'algorithms'

require './heuristic'

def debug(str)
    #puts str
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
  attr_reader :predicate, :values
  @@facts = {}

  def initialize(predicate, values)
    @predicate = predicate
    @values = values
  end

  def Fact.find(predicate, values)
    key = Fact.key(predicate, values)
    @@facts[key] ||= Fact.new(predicate, values)
  end

  def Fact.key(predicate, values)
    predicate.name + values.to_s
  end

  def key
    @key ||= Fact.key(@predicate, @values)
  end

  def to_s
    key
  end
  
  def Fact.instances
    @@facts.values
  end

end

class State
  attr_accessor :facts, :heuristic, :previous, :action

  def initialize(value, predicates)
    @facts = {}
    value.each do |f|
      tokens = f.split
      predicate = predicates[tokens.shift]
      fact = Fact.find(predicate, tokens)
      @facts[fact.key] = fact 
    end
    @heuristic = -1
    @previous = nil
    @action = nil
  end
  
  def clone
    s = State.new([], nil)
    s.facts = @facts.dup
    s
  end

  def add_fact(fact)
    @facts[fact.key] = fact
  end

  def delete_fact(fact)
    @facts.delete(fact.key)
  end

  def each_fact(&block)
    @facts.values.each{|v| yield v }
  end

  def include_fact?(fact)
    return @facts.include?(fact.key)
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

  def find_applicable_actions
    res = []
    Problem.instance.operators.each do |operator|
      Planner.comb(Problem.instance.objects, operator.parameters.size).each do |objs|
        subst = {}
        param = Array.new(operator.parameters)
        objs.each{|o| subst[param.shift] = o}
        action = Action.new(operator, subst)
        res << action if is_applicable?(action)
      end
    end
    
    debug "Applicable actions in state #{self}: "
    debug res
    res
  end
  
  def is_applicable?(action)
    action.operator.precondition.each do |prec|
      f = get_matching_fact(prec, action)
      exists = include_fact?(f)
      if (!exists)
        debug "Action #{action} is not applicable - failed precondition #{prec}"
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
    tokens = tokens[1..-1]
    values = []
    predicate.parameters.each do |p| 
      values << action.substitutions[tokens.shift] 
    end
    f = Fact.find(predicate, values)
  end

  def expand
    actions = find_applicable_actions
    states = []
    actions.each do |action|
      new_state = self.clone
      new_state.apply_action(action)
      new_state.action = action
      new_state.previous = self
      states << new_state
    end
    states
  end

  def solution
    solution = []
    current = self
    while current
      solution << current.action if current.action
      current = current.previous
    end
    solution.reverse
  end

  # TODO write an efficient implementation
  def ==(object)
    if object.equal?(self)
      return true
    elsif !self.class.equal?(object.class)
      return false
    end
    
    object.each_fact{|f| return false if !self.include_fact?(f)}
    self.each_fact{|f| return false if !object.include_fact?(f)}
    true
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
    @current_state.heuristic = @heuristic.calculate_heuristic(@current_state)
    print "Initial distance = #{@current_state.heuristic} "
    while !is_goal_satisfied?(@current_state)
      @current_state = next_state(@current_state)
      printf "\n     h =%3d ", @current_state.heuristic
      if !@current_state
        puts "DEAD END."
        exit
      end
    end
    puts "\nSOLUTION: (#{@current_state.solution.size} actions)"
    puts @current_state.solution.join("\n")
  end
  

  
  def next_state(current_state)

    queue = Containers::PriorityQueue.new{ |x, y| (x <=> y) == -1 }
    queue.push(current_state, current_state.heuristic)
    tabu_states = []

    while !queue.empty?
      state = queue.pop
      return state if state.heuristic < current_state.heuristic
      state.expand.each do |s| 
        print '.'
        s.heuristic = @heuristic.calculate_heuristic(s)
        debug "#{s.heuristic} (queue=#{queue.size})"
        if !tabu_states.include?(s)
          queue.push(s, s.heuristic)
          tabu_states << s
        end
      end
    end

    nil
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

if __FILE__ == $0
  if ARGV.size < 2
    puts "Usage: #{__FILE__} <domain> <problem_number>"
    exit
  end

  planner = Planner.new("domains/#{ARGV[0]}/domain.yml","domains/#{ARGV[0]}/problem#{ARGV[1]}.yml")
  planner.solve
end

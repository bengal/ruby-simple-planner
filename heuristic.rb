

class Heuristic

  INFINITY = 99999999

  def initialize(problem)
    @problem = problem
  end
  
  def choose_best_action(current_state, actions)
    best_heuristic = INFINITY
    best_actions = []
    if rand(100) < 20
      return actions[rand(actions.size)]
    end
    actions.each do |action|
      new_state = current_state.clone
      new_state.apply_action(action)
      h = calculate_heuristic(new_state)
      debug "  Heuristic for action #{action}: #{h}"
      if h == best_heuristic
        best_actions << action
      elsif h < best_heuristic
        best_actions = [action]
        best_heuristic = h
      end
    end
    return best_actions.size == 1 ? 
    best_actions[0] : best_actions[rand(best_actions.size)]
  end
  
  def calculate_heuristic(state)
    
    distance = Hash.new(INFINITY)
    state.each_fact{|f| distance[f] = 0}
    i = 0
    loop do 
      actions = state.find_applicable_actions(true)
      added_facts = []
      actions.each do |action|
        prec_distance = 0
        action.operator.precondition.each do |prec|
          fact = state.get_matching_fact(prec, action)
          if distance[fact] == INFINITY
            puts "ERROR: fact #{fact} has distance #{distance[fact]}"
          end
          prec_distance += distance[fact]
        end
        new_facts = apply_action_relaxed(state, action)
        new_facts.each do |f| 
          if prec_distance + 1 < distance[f]
            distance[f] = prec_distance + 1 
          end
        end
        added_facts += new_facts
      end
      added_facts.each{|f| state.add_fact(f)}
      i += 1
      break if added_facts.empty?
    end
    
    @problem.goal.facts.values.inject(0){|sum,fact| sum + distance[fact]}
  end
  
  private 
  
  def apply_action_relaxed(state, action)
    debug "Appliyng action #{action}"
    added_facts = []
    action.operator.effect.each do |effect|
      fact = state.get_matching_fact(effect, action)
      if effect.split[0].casecmp('not') != 0 && !state.include_fact?(fact)
        added_facts << fact
      end
    end
    added_facts
  end
  
end

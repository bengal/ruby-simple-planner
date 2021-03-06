
class Heuristic

  def initialize(problem)
    @problem = problem
  end
    
  def calculate_heuristic(state)
    
    state = state.clone

    distance = Hash.new(nil)
    state.each_fact{|f| distance[f] = 0}
    i = 0
    loop do 
      actions = state.find_applicable_actions
      added_facts = []
      actions.each do |action|
        prec_distance = 0
        action.operator.precondition.each do |prec|
          fact = state.get_matching_fact(prec, action)
          if !distance[fact]
            puts "ERROR: distance to fact #{fact} can not be computed"
            exit 1
          end
          prec_distance += distance[fact]
        end
        new_facts = apply_action_relaxed(state, action)
        new_facts.each do |f| 
          if !distance[f] || prec_distance + 1 < distance[f]
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

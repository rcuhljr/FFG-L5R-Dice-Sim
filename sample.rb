$prng = Random.new

ring = 4
skill = 1
succ = 3
opp = 0
$NOSTRIFE = false
sample_size = 10000
$DEBUG = sample_size <= 10

def log(msg)
  puts msg if $DEBUG
end


class Result
  attr_accessor :successes,  :strife, :opportunity, :explosive
  def initialize(suc, strife, op, exp)
    @successes = suc
    @strife = strife
    @opportunity = op
    @explosive = exp
    if $NOSTRIFE && strife > 0
      @successes = 0
      @opportunity = 0
      @explosive = 0
    end
  end

  def total
    @successes + @explosive
  end

  def +(y)
    Result.new(y.successes + @successes, y.strife + @strife, y.opportunity + @opportunity, y.explosive + @explosive)
  end

  def inspect
    "s#{@successes}:e#{@explosive}-o#{@opportunity}:f#{@strife}"
  end
end

class RingDie
  @@values = [Result.new(0,0,0,0), Result.new(1,0,0,0), Result.new(1,1,0,0), Result.new(0,1,0,1), Result.new(0,0,1,0), Result.new(0,1,1,0)]
  attr_accessor :val
  def initialize
    my_value = @@values[$prng.rand(5)]
    @val = my_value
    @roll_count = 1
  end

  def explode
    while @val.explosive == @roll_count
      @roll_count += 1
      @val = @val + RingDie.new.val
    end
  end

  def inspect
    @val.inspect
  end
end

class SkillDie
  @@values = [
              Result.new(0,0,0,0), Result.new(0,0,0,0),
              Result.new(1,0,0,0), Result.new(1,0,0,0),
              Result.new(1,0,1,0),
              Result.new(1,1,0,0), Result.new(1,1,0,0),
              Result.new(0,0,0,1),
              Result.new(0,1,0,1),
              Result.new(0,0,1,0),Result.new(0,0,1,0),Result.new(0,0,1,0)
            ]
  attr_accessor :val
  def initialize
    my_value = @@values[$prng.rand(11)]
    # my_value = my_value + SkillDie.new.val if my_value.explosive > 0 #make this an option again for result histogram uses.
    @val = my_value
    @roll_count = 1
  end

    def explode
    while @val.explosive == @roll_count
      @roll_count += 1
      @val = @val + SkillDie.new.val
    end
  end

  def inspect
    @val.inspect
  end
end

class Roll
  def initialize(ring, skill)
    @keep = ring
    @dice = Array.new(ring){RingDie.new} + Array.new(skill){SkillDie.new}
    @dice.sort_by!{|x| x.val.total + x.val.opportunity/10.0 }.reverse!
  end

  def highest_tn
    @dice[0..(@keep-1)].inject(0){|acc, item| acc+item.val.total}
  end

  def can_hit(successes, opportunities)
    #hit with no explosions?
    points = successes+opportunities
    temp = @dice[0..successes-1]
    if temp.last.val.total > 0 #enough successes already
      current_opp = temp.inject(0){|acc, item| acc+item.val.opportunity}
      if (opportunities - current_opp) + temp.size <= @keep &&
         @dice[successes..-1].inject(0){|acc, item| acc+item.val.opportunity} + current_opp >= opportunities
        return true
      end
    end
    success_count = temp.inject(0){|acc, item| acc+item.val.total}
    opportunity_count = [@dice.inject(0){|acc, item| acc+item.val.opportunity}, @keep-success_count].min
    short_fall = points - (success_count + opportunity_count)

    return false unless @dice.any?{|x| x.val.explosive }
    #gamble on explosions
    keepers = generate_best_kept(@dice.dup, short_fall, successes, opportunities)

    return keepers.inject(0){|acc, item| acc+item.val.opportunity} >= opportunities && keepers.inject(0){|acc, item| acc+item.val.total} >= successes
  end

  def inspect
    "#{highest_tn}  #{@dice}"
  end
end

def generate_best_kept(dice, short_fall, successes, opportunities)
    super_dice = dice.select{|x| x.val.opportunity > 0 && x.val.successes > 0}
    opportunity_dice = dice.select{|x| x.val.opportunity > 0 && x.val.total == 0}
    explosion_skill_dice = dice.select{|x| x.val.explosive > 0 && x.is_a?(SkillDie) }
    explosion_ring_dice = dice.select{|x| x.val.explosive > 0 && x.is_a?(RingDie) }

    success_dice = dice.select{|x| x.val.successes > 0 && x.val.opportunity == 0 }

    log("dice: #{@dice}")
    log("sf: #{short_fall}")
    log("super: #{super_dice}")
    log("opportunity: #{opportunity_dice}")
    log("explosion_skill_dice: #{explosion_skill_dice}")
    log("explosion_ring_dice: #{explosion_ring_dice}")
    log("success_dice: #{success_dice}")

  keepers = []
  while keepers.size < @keep
    log("keepers: #{keepers}")
    if keepers.size < short_fall && explosion_skill_dice.first #keep any exploding dice if we've not kept enough to reach our goal
      keepers << explosion_skill_dice.shift
      keepers.last.explode
      log("exploded to: #{keepers.last.inspect}")
    elsif keepers.size < short_fall && explosion_ring_dice.first
      keepers << explosion_ring_dice.shift
      keepers.last.explode
      log("exploded to: #{keepers.last.inspect}")
    elsif super_dice.first  #If we have any super dice at this point, keep them, they're strictly better than successes or extra explosions as far as opportunity goes
      keepers << super_dice.shift #We shouldn't use this step if we're already at our opportunity cap, but it's almost impossibly rare to push out explosions with these results and still hit the target
    elsif opportunity_dice.first && keepers.inject(0){|acc, item| acc+item.val.opportunity} < opportunities #If we don't have enough opps yet, keep any preferenterially
      keepers << opportunity_dice.shift
    elsif explosion_skill_dice.first
      keepers << explosion_skill_dice.shift
      keepers.last.explode
      log("exploded to: #{keepers.last.inspect}")
    elsif explosion_ring_dice.first
      keepers << explosion_ring_dice.shift
      keepers.last.explode
      log("exploded to: #{keepers.last.inspect}")
    elsif success_dice.first
      keepers << success_dice.shift
    else
      break
    end
  end
  log("keepers: #{keepers}")
  keepers
end

class Sampler

  def roll(ring, skill, count)
    Array.new(count){ Roll.new(ring, skill) }
  end

end


sampler = Sampler.new

sample = sampler.roll(ring, skill, sample_size)

raw_res = sample.map{|x| x.highest_tn}

hist = Hash.new(0)

raw_res.each{|x| hist[x] += 1}

puts hist.inspect

puts "Results for #{ring}/#{skill} roll"

#Not relvant with delayed execution of explosions currently.
# hist.keys.sort.each do |tn|
#   puts "tn:#{tn} #{(hist[tn]/sample_size.to_f*100).round(3)}"
# end

raw_target = sample.map{|x| x.can_hit(succ, opp)}

puts "chance to hit #{succ}/#{opp}: #{raw_target.select{|x| x}.size.to_f/sample.size}"
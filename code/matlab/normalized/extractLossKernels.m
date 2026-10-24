function kernel = extractLossKernels(solution)
%extractLossKernels Per-switch squared-current weights; zero-deadtime baseline only.
arguments
    solution (1,1) struct
end
tau = solution.t_over_T;
i = solution.wave.i_A;
upper = lcc3v2Gate(tau);
switchMeanSquare = zeros(1,6);
switchPeak = zeros(1,6);
for phase = 1:3
    masks = [upper(:,phase) 1-upper(:,phase)];
    for side = 1:2
        index = 2*(phase-1)+side;
        switchMeanSquare(index) = mean(i(:,phase).^2.*masks(:,side));
        switchPeak(index) = max(abs(i(:,phase).*masks(:,side)));
    end
    pair = 2*(phase-1)+(1:2);
    switchMeanSquare(pair) = switchMeanSquare(pair)*solution.metric.iLine_rms_A(phase)^2/sum(switchMeanSquare(pair));
end
turnoffTau = [0.5 1 1/6 2/3 5/6 1/3];
turnonTau = [0 0.5 2/3 1/6 1/3 5/6];
[offStates,~] = lcc3v2Evaluate(solution,turnoffTau.');
[onStates,~] = lcc3v2Evaluate(solution,turnonTau.');
g = lcc3v2Geometry();
offLines = offStates(:,1:2)*g.U';
onLines = onStates(:,1:2)*g.U';
offCurrent = zeros(1,6);
onCurrent = zeros(1,6);
for index = 1:6
    phase = ceil(index/2);
    direction = 1-2*mod(index+1,2);
    offCurrent(index) = direction*offLines(index,phase);
    onCurrent(index) = direction*onLines(index,phase);
end
kernel = struct('switch_names',{{'S1','S4','S2','S5','S3','S6'}}, ...
    'MOS_meanSquare_A2',switchMeanSquare,'MOS_rms_A',sqrt(switchMeanSquare), ...
    'MOS_peak_A',switchPeak,'MOS_Ioff_signed_A',offCurrent, ...
    'MOS_Ion_signed_A',onCurrent,'MOS_sumMeanSquare_A2',sum(switchMeanSquare), ...
    'diode_mean_A',mean([solution.wave.diodeUpper_A solution.wave.diodeLower_A],1), ...
    'diode_meanSquare_A2',mean([solution.wave.diodeUpper_A solution.wave.diodeLower_A].^2,1), ...
    'rectifier_constantVf_W',solution.metric.Pdiode_W, ...
    'input_resistor_W',solution.metric.PRin_W, ...
    'scope','ideal complementary gating; no physical deadtime or Coss; no ZVS certification');
end

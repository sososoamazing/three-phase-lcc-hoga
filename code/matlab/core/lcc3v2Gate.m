function d = lcc3v2Gate(tau)
%lcc3v2Gate Right-continuous upper gates; phase is the original positive shift.
arguments
    tau (:,1) double {mustBeFinite}
end
t = mod(tau,1);
d = double([t < 0.5, t < 1/6 | t >= 2/3, t >= 1/3 & t < 5/6]);
end

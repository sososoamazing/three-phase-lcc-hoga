function solution = integrateHogaInput(solution)
%INTEGRATEHOGAINPUT Exact piecewise gate/Fourier averages, without sample alias.
g = lcc3v2Geometry();
p = solution.params;
h = solution.h.';
I = solution.coeff.i_alpha_beta;
pin = 0; pr = 0;
for segment = 1:6
    a = (segment-1)/6; b = segment/6; width = b-a;
    q = lcc3v2Gate((a+b)/2)*g.U;
    currentCoeff = q*I;
    area = width*normalizedSinc(h*width).*exp(1i*pi*h*(a+b));
    hh = h.'+h;
    pairArea = width*normalizedSinc(hh*width).*exp(1i*pi*hh*(a+b));
    pin = pin+p.Vin*real(currentCoeff*area.');
    pr = pr+p.Rin*real(currentCoeff*pairArea*currentCoeff.');
end

if ~isfield(solution.metric,'uniform_grid_Pin_W')
    solution.metric.uniform_grid_Pin_W = solution.metric.Pin_W;
    solution.metric.uniform_grid_PRin_W = solution.metric.PRin_W;
end
solution.metric.Pin_W = pin; solution.metric.PRin_W = pr;
solution.metric.power_residual_W = pin-pr-(solution.Vo_V+2*p.Vf_rect)*solution.metric.Irect_mean_A;
solution.metric.power_relative_residual = abs(solution.metric.power_residual_W)/max(abs(pin),1e-6);
solution.input_power_integration = 'Exact six-gate-interval integrals of finite Fourier currents; no uniform-grid gate product';
end

function y = normalizedSinc(x)
y = ones(size(x));
take = x~=0;
y(take) = sin(pi*x(take))./(pi*x(take));
end

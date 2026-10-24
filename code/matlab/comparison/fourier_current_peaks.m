function peak=fourier_current_peaks(sol)
%fourier_current_peaks Refine every derivative sign-changing bracket in a cycle.
g=lcc3v2Geometry();C=g.U*sol.coeff.i_alpha_beta;h=sol.h.';
t=(0:4096)'/4096;D=real(exp(2i*pi*t*h)*(C.*(2i*pi*h)).');
peak=zeros(1,3);
for phase=1:3
    indices=find(D(1:end-1,phase).*D(2:end,phase)<0);
    candidates=[0;1;t(D(:,phase)==0)];
    derivative=@(u)real(sum(C(phase,:).*(2i*pi*h).*exp(2i*pi*h*u)));
    for k=indices.'
        candidates(end+1)=fzero(derivative,t([k k+1]),optimset('TolX',1e-13)); %#ok<AGROW>
    end
    peak(phase)=max(abs(real(exp(2i*pi*candidates*h)*C(phase,:).')));
end
end

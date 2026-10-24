function h=waveform_harmonics(waveform,maxOrder)
%waveform_harmonics Positive-order peak amplitudes from a complete uniform cycle.
N=size(waveform.i_A,1);k=(0:maxOrder)';
f=fft(waveform.i_A)/N;v=fft(waveform.vDelta_V)/N;
h=struct('order',k,'i_complex',f(k+1,:),'i_peak',2*abs(f(k+1,:)), ...
    'vDelta_complex',v(k+1,:),'vDelta_peak',2*abs(v(k+1,:)));
h.i_peak(1,:)=abs(f(1,:));h.vDelta_peak(1,:)=abs(v(1,:));
h.convention='complex coefficients Xk; positive-order peak amplitude=2*abs(Xk), DC=abs(X0)';
end

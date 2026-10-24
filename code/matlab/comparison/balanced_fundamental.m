function b=balanced_fundamental(cfg)
%balanced_fundamental Independently integrate the six drive sectors (peak phasors).
b.phase=exp(1i*[0;2*pi/3;4*pi/3]);
b.P=eye(3)-ones(3)/3;
b.B=[1 0 -1;-1 1 0;0 -1 1];
b.E=2*cfg.Vin/(1i*pi);
b.M0=zeros(3);b.M2=complex(zeros(3));
for k=1:6
    lo=(k-1)/6;hi=k/6;t=(lo+hi)/2;
    d=double([t<.5;t<1/6 || t>=2/3;t>=1/3 && t<5/6]);p=b.P*d;
    b.M0=b.M0+(hi-lo)*(p*p');
    c=(exp(-4i*pi*lo)-exp(-4i*pi*hi))/(4i*pi);
    b.M2=b.M2+c*(p*p');
end
b.a=(b.phase'*b.M0*b.phase)/3;
b.b=(b.phase'*b.M2*conj(b.phase))/3;
end

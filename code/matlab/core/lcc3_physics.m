function varargout = lcc3_physics(action,varargin)
% Shared PHYSICAL definitions only; two independent numerical solvers.
% Actions: 'basis', 'gate', 'project', 'fourier_drive'. No base workspace.
switch lower(action)
 case 'basis'
  B=[1 0 -1;-1 1 0;0 -1 1];
  U=[1/sqrt(2) 1/sqrt(6);-1/sqrt(2) 1/sqrt(6);0 -2/sqrt(6)];
  C=U'*B*U;
  varargout={U,B,C};
 case 'gate'
  t=mod(varargin{1}(:),1); d=double([t>0 & t<.5, t<1/6 | t>2/3, t>1/3 & t<5/6]);
  varargout={d};
 case 'project'
  Y=varargin{1}; V=varargin{2}; U=varargin{3};
  assert(V>0 && size(Y,2)==2,'Projection requires V>0 and N-by-2 coordinates');
  nodes=[2 -1 -1; -1 2 -1; -1 -1 2; -2 1 1; 1 -2 1; 1 1 -2]*V/3;
  vertices=nodes*U;
  [~,order]=sort(atan2(vertices(:,2),vertices(:,1)));
  vertices=vertices(order,:);
  E3=Y*U'; inside=max(E3,[],2)-min(E3,[],2)<=V+1e-12*max(V,1);
  Z=Y; miss=find(~inside);
  if ~isempty(miss)
   X=Y(miss,:); best=inf(numel(miss),1); K=zeros(size(X));
   for k=1:6
    a=vertices(k,:); b=vertices(mod(k,6)+1,:); ab=b-a;
    w=max(0,min(1,((X-a)*ab')/(ab*ab')));
    q=a+w.*ab; dst=sum((X-q).^2,2);
    upd=dst<best; K(upd,:)=q(upd,:); best(upd)=dst(upd);
   end
   Z(miss,:)=K;
  end
  varargout={Z};
 case 'fourier_drive'
  H=varargin{1}; U=varargin{2};
  z=(-2*H:2*H).'; Pz=complex(zeros(2,numel(z)));
  Qz=complex(zeros(2,2,numel(z)));
  edges=(0:6)/6;
  for s=1:6
   a=edges(s);b=edges(s+1); mid=(a+b)/2;
   d=lcc3_physics('gate',mid);p=U'*d';
   ck=interval_coef(z,a,b);
   Pz=Pz+p*ck.';
   for k=1:numel(z), Qz(:,:,k)=Qz(:,:,k)+(p*p.')*ck(k); end
  end
  varargout={z,Pz,Qz};
 otherwise
  error('LCC3:UnknownAction','Unknown action: %s',action);
end
end
function c=interval_coef(h,a,b)
x=pi*h*(b-a); s=ones(size(x)); ix=x~=0; s(ix)=sin(x(ix))./x(ix);
c=(b-a)*s.*exp(-1i*pi*h*(a+b));
end

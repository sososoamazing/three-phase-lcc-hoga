function g = lcc3v2Geometry()
%lcc3v2Geometry Oriented winding incidence and all six rectifier inequalities.
g.B = [1 0 -1; -1 1 0; 0 -1 1];
g.U = [1/sqrt(2) 1/sqrt(6); -1/sqrt(2) 1/sqrt(6); 0 -2/sqrt(6)];
g.C = g.U'*g.B*g.U;
g.pairs = [1 2; 1 3; 2 1; 2 3; 3 1; 3 2];
g.A = g.U(g.pairs(:,1),:) - g.U(g.pairs(:,2),:);
end
